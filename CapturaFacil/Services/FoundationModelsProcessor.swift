// MARK: - FoundationModelsProcessor.swift
// Capa de Comprensión: transforma [RecognizedBlock] → StructuredContent
// usando el modelo de lenguaje on-device de Apple (Foundation Models, iOS 26+).
//
// Cambios v2:
//   - Heurística de títulos: scoring multi-señal (geometría + posición + texto)
//     en lugar de solo boundingBox.height.
//   - Schema de fórmulas ampliado: el LLM devuelve pasos de solución estructurados
//     (MathFormulaDTO) en lugar de strings crudos.
//   - CaptureService puede mapear los pasos directamente a [SolutionStep].

import Foundation
import FoundationModels
import CoreGraphics

// MARK: - Errores

enum FoundationModelsError: LocalizedError {
    case modelUnavailable
    case allBlocksDiscarded
    case invalidJSONResponse(String)
    case decodingFailed(Error)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "El modelo on-device no está disponible. Requiere iOS 26 con Apple Intelligence habilitado."
        case .allBlocksDiscarded:
            return "Todos los bloques tienen confianza demasiado baja. Intenta con una imagen más nítida."
        case .invalidJSONResponse(let raw):
            return "Respuesta JSON inválida del modelo: \(raw.prefix(120))…"
        case .decodingFailed(let e):
            return "Error al decodificar la respuesta: \(e.localizedDescription)"
        }
    }
}

// MARK: - Rol semántico heurístico

enum BlockRole: String {
    case heading1 = "TITULO_PRINCIPAL"
    case heading2 = "SUBTITULO"
    case body     = "CUERPO"
    case dubious  = "DUDOSO"
}

// MARK: - DTOs internos para decodificación

/// Paso de solución tal como lo devuelve el LLM.
private struct SolutionStepDTO: Decodable {
    let number:      Int
    let description: String
    let expression:  String
}

/// Fórmula con pasos tal como la devuelve el LLM.
private struct MathFormulaDTO: Decodable {
    let rawText: String
    let steps:   [SolutionStepDTO]
}

/// Subconjunto de StructuredContent que genera el LLM.
/// Usa MathFormulaDTO en lugar de String para capturar los pasos.
private struct StructuredContentDTO: Decodable {
    let mainTitle:   String
    let summary:     String
    let sections:    [Section]
    let keyConcepts: [String]
    let mathFound:   [MathFormulaDTO]?
}

// MARK: - Resultado público

/// ProcessedStructuredContent enriquecido con fórmulas que ya incluyen pasos de solución.
/// CaptureService consume este tipo para construir el Capture final.
struct ProcessedStructuredContent {
    let mainTitle:          String
    let summary:            String
    let sections:           [Section]
    let keyConcepts:        [String]
    /// Fórmulas ya parseadas con sus pasos. Nil si no hay matemáticas.
    let mathFormulas:       [ParsedMathFormula]?
    /// Campo legacy para compatibilidad con código que solo necesita el string crudo.
    var mathFound: [String]? { mathFormulas?.map(\.rawText) }
    let processingMetadata: ProcessingMetadata
}

/// Fórmula parseada lista para mapear a MathFormula del dominio.
struct ParsedMathFormula {
    let rawText: String
    let steps:   [ParsedSolutionStep]
}

struct ParsedSolutionStep {
    let number:      Int
    let description: String
    let expression:  String
}

// MARK: - Procesador principal

final class FoundationModelsProcessor: InformationProcessor {

    // MARK: Umbrales configurables

    var discardThreshold: Float    = 0.30
    var dubiousThreshold: Float    = 0.50
    var h1HeightThreshold: CGFloat = 0.06
    var h2HeightThreshold: CGFloat = 0.035

    // MARK: - InformationProcessor

    func process(blocks: [RecognizedBlock]) async throws -> any Sendable {
        let start = Date()

        let (usable, metadata) = filterAndClassify(blocks)
        guard !usable.isEmpty else { throw FoundationModelsError.allBlocksDiscarded }

        let systemPrompt = buildSystemPrompt()
        let userPrompt   = buildUserPrompt(from: usable)
        let rawJSON      = try await callFoundationModel(system: systemPrompt, user: userPrompt)
        let content      = try decodeResponse(rawJSON, metadata: metadata)

        return patchProcessingTime(content, start: start)
    }

    // MARK: - Paso 1: Filtrado y clasificación multi-señal

    private func filterAndClassify(
        _ blocks: [RecognizedBlock]
    ) -> (usable: [(block: RecognizedBlock, role: BlockRole)], metadata: ProcessingMetadata) {

        var discarded = 0
        var flagged   = 0
        var usable: [(block: RecognizedBlock, role: BlockRole)] = []

        let sorted = blocks.sorted { $0.readingOrder < $1.readingOrder }

        // Pre-calcular estadísticas del conjunto para señales relativas
        let heights     = sorted.map(\.boundingBox.height)
        let maxHeight   = heights.max() ?? 1
        let meanHeight  = heights.isEmpty ? 1 : heights.reduce(0, +) / CGFloat(heights.count)

        for block in sorted {
            if block.confidence < discardThreshold {
                discarded += 1
                continue
            }
            let role: BlockRole
            if block.confidence < dubiousThreshold {
                role = .dubious
                flagged += 1
            } else {
                role = semanticRole(
                    for: block,
                    maxHeight: maxHeight,
                    meanHeight: meanHeight,
                    isFirstBlock: block.readingOrder == sorted.first?.readingOrder
                )
            }
            usable.append((block, role))
        }

        let metadata = ProcessingMetadata(
            totalBlocksReceived: blocks.count,
            blocksDiscarded:     discarded,
            blocksFlagged:       flagged,
            discardThreshold:    discardThreshold,
            processingTimeMs:    0
        )
        return (usable, metadata)
    }

    /// Clasificación multi-señal: combina geometría, posición y análisis textual.
    ///
    /// Señales usadas:
    ///   1. Altura relativa al máximo del conjunto (texto más grande = encabezado)
    ///   2. Altura absoluta normalizada (umbral fijo para H1/H2)
    ///   3. Posición Y alta en la imagen (y_vision > 0.75 → probablemente arriba)
    ///   4. Centrado horizontal (xCenter ≈ 0.5 ± 0.15 → posible título)
    ///   5. Es el primer bloque en orden de lectura
    ///   6. Texto corto (≤ 6 palabras → más probable que sea encabezado que cuerpo)
    ///   7. Todo en mayúsculas o termina en ":"
    ///
    /// Sistema de puntos: suma señales → umbral para H1 / H2 / CUERPO
    private func semanticRole(
        for block: RecognizedBlock,
        maxHeight: CGFloat,
        meanHeight: CGFloat,
        isFirstBlock: Bool
    ) -> BlockRole {

        var score: Int = 0
        let bb   = block.boundingBox
        let text = block.text.trimmingCharacters(in: .whitespaces)

        // ── Señal 1: altura relativa ──────────────────────────────────────────
        // Si este bloque tiene la letra más grande (o casi) del conjunto, puntúa fuerte.
        let heightRatio = maxHeight > 0 ? bb.height / maxHeight : 0
        if heightRatio >= 0.90 { score += 4 }      // letra dominante del documento
        else if heightRatio >= 0.70 { score += 2 }  // letra grande pero no la máxima

        // ── Señal 2: altura absoluta (umbrales fijos de Vision) ───────────────
        if bb.height >= h1HeightThreshold  { score += 3 }
        else if bb.height >= h2HeightThreshold { score += 1 }

        // ── Señal 3: posición vertical alta (Vision: y=1 = parte superior) ────
        // Un bloque cuyo borde superior supera el 75% de la altura de la imagen
        // está en el tercio superior → probable encabezado.
        let topEdge = bb.origin.y + bb.height
        if topEdge >= 0.80 { score += 2 }
        else if topEdge >= 0.65 { score += 1 }

        // ── Señal 4: centrado horizontal ──────────────────────────────────────
        let xCenter = bb.origin.x + bb.width / 2
        let distFromCenter = abs(xCenter - 0.5)
        if distFromCenter <= 0.12 { score += 2 }   // muy centrado
        else if distFromCenter <= 0.20 { score += 1 }

        // ── Señal 5: primer bloque en la imagen ───────────────────────────────
        if isFirstBlock { score += 2 }

        // ── Señal 6: longitud del texto ───────────────────────────────────────
        let wordCount = text.split(separator: " ").count
        if wordCount <= 4  { score += 2 }   // muy corto → probable encabezado
        else if wordCount <= 7  { score += 1 }
        else if wordCount >= 20 { score -= 2 } // párrafo largo → probablemente cuerpo

        // ── Señal 7: patrones textuales ───────────────────────────────────────
        let isAllCaps    = text == text.uppercased() && text.count > 2
        let endsWithColon = text.hasSuffix(":")
        if isAllCaps     { score += 2 }
        if endsWithColon { score += 1 }

        // ── Decisión final por umbral de puntos ───────────────────────────────
        // H1: score ≥ 7  (múltiples señales fuertes de título principal)
        // H2: score ≥ 4  (algunas señales de encabezado secundario)
        // CUERPO: resto
        switch score {
        case 7...:  return .heading1
        case 4..<7: return .heading2
        default:    return .body
        }
    }

    // MARK: - Paso 2a: System prompt

    private func buildSystemPrompt() -> String {
        """
        Eres un asistente especializado en accesibilidad educativa para personas con \
        dislexia, discalculia y disgrafia. Recibirás bloques de texto extraídos con OCR \
        de notas de clase, pizarrones o presentaciones, junto con su posición espacial \
        normalizada, un rol semántico inferido por geometría y una puntuación heurística \
        de título (titleScore).

        REGLAS OBLIGATORIAS:
        1. JERARQUÍA: Respeta los roles TITULO_PRINCIPAL y SUBTITULO indicados. Si \
           ningún bloque tiene rol TITULO_PRINCIPAL pero hay uno con titleScore alto, \
           úsalo como título principal. Si todos los scores son bajos, infiere el título \
           del contexto semántico del texto.
        2. SIMPLIFICACIÓN: Reescribe el contenido de CUERPO en lenguaje claro y \
           digerible. Conserva ÍNTEGRA la terminología técnica o científica.
        3. MATEMÁTICAS: Detecta y extrae TODAS las fórmulas, ecuaciones y expresiones \
           matemáticas al campo `mathFound`. Para cada una genera pasos de solución o \
           de interpretación. Si no hay matemáticas, devuelve null en `mathFound`.
        4. PASOS DE FÓRMULAS: Cada paso debe tener: número secuencial, descripción en \
           lenguaje natural (qué se hace en ese paso), y la expresión matemática \
           correspondiente. Mínimo 2 pasos, máximo 6. Si la fórmula es una definición \
           sin solución numérica, describe sus partes componentes como pasos.
        5. DUDOSOS: Usa los bloques marcados DUDOSO solo si aportan contexto claro.
        6. RESUMEN: El campo `summary` debe ser EXACTAMENTE 2 oraciones.
        7. CONCEPTOS: Extrae entre 3 y 7 términos clave.
        8. SALIDA: Responde ÚNICAMENTE con el objeto JSON. Sin markdown, sin texto extra.

        ESQUEMA JSON REQUERIDO (copia exacta de claves y tipos):
        {
          "mainTitle": "string",
          "summary": "string",
          "sections": [
            { "title": "string", "bullets": ["string"], "confidenceLevel": 0.0 }
          ],
          "keyConcepts": ["string"],
          "mathFound": [
            {
              "rawText": "string",
              "steps": [
                { "number": 1, "description": "string", "expression": "string" }
              ]
            }
          ] | null
        }
        """
    }

    // MARK: - Paso 2b: User prompt con contexto espacial y titleScore

    private func buildUserPrompt(
        from usable: [(block: RecognizedBlock, role: BlockRole)]
    ) -> String {
        let separator = String(repeating: "─", count: 60)
        var lines = [
            "CONTENIDO (ordenado por posición de lectura):",
            "Formato: [ROL | orden:N | y_norm:F | alto_norm:F | xCenter:F | titleScore:N | confianza:F%] texto",
            separator
        ]

        // Pre-calcular maxHeight para incluir heightRatio en el prompt
        let maxHeight = usable.map { $0.block.boundingBox.height }.max() ?? 1

        for (block, role) in usable {
            let bb       = block.boundingBox
            let y        = String(format: "%.3f", bb.origin.y)
            let h        = String(format: "%.3f", bb.height)
            let xCenter  = String(format: "%.3f", bb.origin.x + bb.width / 2)
            let conf     = String(format: "%.0f%%", block.confidence * 100)
            let score    = computeTitleScore(block: block, maxHeight: maxHeight)
            lines.append(
                "[\(role.rawValue) | orden:\(block.readingOrder) | y_norm:\(y) | alto_norm:\(h) | xCenter:\(xCenter) | titleScore:\(score) | confianza:\(conf)] \(block.text)"
            )
        }

        lines += [
            separator,
            "Analiza el contenido y devuelve el JSON. Agrupa bloques CUERPO bajo el " +
            "SUBTITULO más cercano que los preceda. Si no hay SUBTITULO previo, " +
            "usa el TITULO_PRINCIPAL. Para las fórmulas en mathFound, genera pasos " +
            "que expliquen cómo resolverlas o interpretar cada componente."
        ]

        return lines.joined(separator: "\n")
    }

    /// Calcula el titleScore numérico para incluirlo en el prompt.
    /// El modelo puede usarlo como señal adicional incluso si el rol geométrico
    /// no coincide perfectamente (ej. un título pequeño con centrado perfecto).
    private func computeTitleScore(block: RecognizedBlock, maxHeight: CGFloat) -> Int {
        var score = 0
        let bb   = block.boundingBox
        let text = block.text.trimmingCharacters(in: .whitespaces)

        let heightRatio = maxHeight > 0 ? bb.height / maxHeight : 0
        if heightRatio >= 0.90 { score += 4 } else if heightRatio >= 0.70 { score += 2 }

        if bb.height >= h1HeightThreshold  { score += 3 }
        else if bb.height >= h2HeightThreshold { score += 1 }

        let topEdge = bb.origin.y + bb.height
        if topEdge >= 0.80 { score += 2 } else if topEdge >= 0.65 { score += 1 }

        let xCenter = bb.origin.x + bb.width / 2
        if abs(xCenter - 0.5) <= 0.12 { score += 2 } else if abs(xCenter - 0.5) <= 0.20 { score += 1 }

        let wordCount = text.split(separator: " ").count
        if wordCount <= 4 { score += 2 } else if wordCount <= 7 { score += 1 }
        else if wordCount >= 20 { score -= 2 }

        if text == text.uppercased() && text.count > 2 { score += 2 }
        if text.hasSuffix(":") { score += 1 }

        return max(0, score)
    }

    // MARK: - Paso 3: Llamada a Foundation Models

    private func callFoundationModel(system: String, user: String) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw FoundationModelsError.modelUnavailable
        }
        let session  = LanguageModelSession(instructions: system)
        let response = try await session.respond(to: user)
        return response.content
    }

    // MARK: - Paso 4: Decodificación vía DTO

    private func decodeResponse(_ raw: String, metadata: ProcessingMetadata) throws -> ProcessedStructuredContent {
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw FoundationModelsError.invalidJSONResponse(raw)
        }

        do {
            let dto = try JSONDecoder().decode(StructuredContentDTO.self, from: data)

            // Mapear MathFormulaDTO → ParsedMathFormula
            let parsedFormulas: [ParsedMathFormula]? = dto.mathFound.map { formulas in
                formulas.map { f in
                    ParsedMathFormula(
                        rawText: f.rawText,
                        steps: f.steps.map { s in
                            ParsedSolutionStep(
                                number:      s.number,
                                description: s.description,
                                expression:  s.expression
                            )
                        }
                    )
                }
            }

            return ProcessedStructuredContent(
                mainTitle:          dto.mainTitle,
                summary:            dto.summary,
                sections:           dto.sections,
                keyConcepts:        dto.keyConcepts,
                mathFormulas:       parsedFormulas,
                processingMetadata: metadata
            )
        } catch {
            throw FoundationModelsError.decodingFailed(error)
        }
    }

    // MARK: - Paso 5: Tiempo de procesamiento

    private func patchProcessingTime(_ content: ProcessedStructuredContent, start: Date) -> ProcessedStructuredContent {
        let ms   = Date().timeIntervalSince(start) * 1000
        let meta = ProcessingMetadata(
            totalBlocksReceived: content.processingMetadata.totalBlocksReceived,
            blocksDiscarded:     content.processingMetadata.blocksDiscarded,
            blocksFlagged:       content.processingMetadata.blocksFlagged,
            discardThreshold:    content.processingMetadata.discardThreshold,
            processingTimeMs:    ms
        )
        return ProcessedStructuredContent(
            mainTitle:          content.mainTitle,
            summary:            content.summary,
            sections:           content.sections,
            keyConcepts:        content.keyConcepts,
            mathFormulas:       content.mathFormulas,
            processingMetadata: meta
        )
    }
}

