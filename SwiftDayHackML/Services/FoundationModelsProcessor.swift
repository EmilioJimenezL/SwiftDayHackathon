// MARK: - FoundationModelsProcessor.swift
// Capa de Comprensión: transforma [RecognizedBlock] → StructuredContent
// usando el modelo de lenguaje on-device de Apple (Foundation Models, iOS 26+).
//
// Pipeline:
//   [RecognizedBlock]
//     ├─ 1. Filtrado por confidence   (descarta ruido, marca dudosos)
//     ├─ 2. Clasificación heurística  (geometría → rol semántico pre-inferido)
//     ├─ 3. Serialización del prompt  (texto estructurado con contexto espacial)
//     ├─ 4. LanguageModelSession      (on-device, sin red)
//     └─ 5. Decodificación + metadatos
//               ↓
//        StructuredContent
//
// Por qué on-device y no API externa:
//   - Privacidad: ningún dato educativo sale del dispositivo del alumno.
//   - Fiabilidad: sin dependencia de red para demos.
//   - Alineación con valores Apple: Apple Intelligence como diferenciador.

import Foundation
import FoundationModels  // iOS 26+ / macOS 26+  (requiere Xcode 26 beta)
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
            return "Todos los bloques tienen confianza demasiado baja para procesar. Intenta con una imagen más nítida."
        case .invalidJSONResponse(let raw):
            return "Respuesta JSON inválida del modelo: \(raw.prefix(120))…"
        case .decodingFailed(let e):
            return "Error al decodificar la respuesta: \(e.localizedDescription)"
        }
    }
}

// MARK: - Rol semántico heurístico

/// Rol inferido por geometría antes de llamar al LLM.
/// Se incluye en el prompt para que el modelo tenga contexto espacial explícito
/// sin necesidad de ver la imagen ni de haber sido fine-tuneado en pizarrones.
enum BlockRole: String {
    case heading1 = "TITULO_PRINCIPAL"
    case heading2 = "SUBTITULO"
    case body     = "CUERPO"
    case dubious  = "DUDOSO"
}

// MARK: - Procesador principal

final class FoundationModelsProcessor: InformationProcessor {

    // MARK: Umbrales configurables desde LexiScanApp

    /// Bloques con confidence < este valor se descartan completamente.
    var discardThreshold: Float    = 0.30

    /// Bloques con confidence en [discardThreshold, dubiousThreshold) se marcan DUDOSO.
    var dubiousThreshold: Float    = 0.50

    /// Altura normalizada (Vision [0,1]) mínima para considerar un bloque como H1.
    var h1HeightThreshold: CGFloat = 0.06

    /// Altura normalizada mínima para H2.
    var h2HeightThreshold: CGFloat = 0.035

    // MARK: - InformationProcessor

    func process(blocks: [RecognizedBlock]) async throws -> any Sendable {
        let start = Date()

        // ── 1. Filtrado y clasificación ──────────────────────────────────────
        let (usable, metadata) = filterAndClassify(blocks)
        guard !usable.isEmpty else { throw FoundationModelsError.allBlocksDiscarded }

        // ── 2. Construcción del prompt ───────────────────────────────────────
        let systemPrompt = buildSystemPrompt()
        let userPrompt   = buildUserPrompt(from: usable)

        // ── 3. Llamada al modelo on-device ───────────────────────────────────
        let rawJSON = try await callFoundationModel(system: systemPrompt, user: userPrompt)

        // ── 4. Decodificación ────────────────────────────────────────────────
        let content = try decodeResponse(rawJSON, metadata: metadata)

        // ── 5. Inyectar tiempo total de Fase 2 ───────────────────────────────
        return patchProcessingTime(content, start: start)
    }

    // MARK: - Paso 1: Filtrado y clasificación heurística

    private func filterAndClassify(
        _ blocks: [RecognizedBlock]
    ) -> (usable: [(block: RecognizedBlock, role: BlockRole)], metadata: ProcessingMetadata) {

        var discarded = 0
        var flagged   = 0
        var usable: [(block: RecognizedBlock, role: BlockRole)] = []

        // Ordenar por readingOrder garantiza que el prompt refleje el flujo
        // visual real del pizarrón de arriba a abajo.
        for block in blocks.sorted(by: { $0.readingOrder < $1.readingOrder }) {
            if block.confidence < discardThreshold {
                discarded += 1
                continue
            }
            let role: BlockRole
            if block.confidence < dubiousThreshold {
                role = .dubious
                flagged += 1
            } else {
                role = geometricRole(for: block)
            }
            usable.append((block, role))
        }

        let metadata = ProcessingMetadata(
            totalBlocksReceived: blocks.count,
            blocksDiscarded:     discarded,
            blocksFlagged:       flagged,
            discardThreshold:    discardThreshold,
            processingTimeMs:    0   // se patchea en el paso 5
        )
        return (usable, metadata)
    }

    /// Infiere el rol del bloque basándose exclusivamente en la altura normalizada
    /// de su boundingBox. Mayor altura → letra más grande → probablemente encabezado.
    private func geometricRole(for block: RecognizedBlock) -> BlockRole {
        switch block.boundingBox.height {
        case h1HeightThreshold...:    return .heading1
        case h2HeightThreshold...:    return .heading2
        default:                      return .body
        }
    }

    // MARK: - Paso 2a: System prompt (reglas de accesibilidad)

    private func buildSystemPrompt() -> String {
        """
        Eres un asistente especializado en accesibilidad educativa para personas con \
        dislexia y discalculia. Recibirás bloques de texto extraídos con OCR de un \
        pizarrón escolar, junto con su posición espacial normalizada y un rol semántico \
        inferido por geometría.

        REGLAS OBLIGATORIAS:
        1. JERARQUÍA: Respeta los roles TITULO_PRINCIPAL, SUBTITULO y CUERPO indicados. \
           Si un bloque TITULO_PRINCIPAL no tiene sentido como título, promueve el \
           siguiente bloque más prominente.
        2. SIMPLIFICACIÓN: Reescribe el contenido de CUERPO en lenguaje claro (máximo \
           nivel secundaria). Conserva ÍNTEGRA la terminología técnica o científica.
        3. MATEMÁTICAS: Extrae fórmulas y ecuaciones al campo `mathFound`. Normaliza \
           la notación: ^ para potencias, * para multiplicación. Si no hay matemáticas, \
           devuelve null.
        4. DUDOSOS: Usa los bloques marcados DUDOSO solo si aportan contexto claro; \
           ignóralos si parecen ruido o texto ilegible.
        5. RESUMEN: El campo `summary` debe ser EXACTAMENTE 2 oraciones. Primera: \
           describe el tema principal. Segunda: objetivo o conclusión clave.
        6. CONCEPTOS: Extrae entre 3 y 7 términos o frases clave.
        7. SALIDA: Responde ÚNICAMENTE con el objeto JSON. Sin texto previo, \
           sin bloques de código markdown, sin explicaciones adicionales.

        ESQUEMA JSON REQUERIDO (copia exacta de las claves):
        {
          "mainTitle": "string",
          "summary": "string",
          "sections": [
            { "title": "string", "bullets": ["string"], "confidenceLevel": 0.0 }
          ],
          "keyConcepts": ["string"],
          "mathFound": ["string"] | null
        }
        """
    }

    // MARK: - Paso 2b: User prompt con contexto espacial serializado

    /// Serializa los bloques incluyendo posición Y, altura y confianza.
    /// El modelo puede razonar sobre jerarquía visual sin ver la imagen.
    /// Ejemplo de línea generada:
    ///   [TITULO_PRINCIPAL | orden:0 | y_norm:0.921 | alto_norm:0.072 | confianza:94%] Fotosíntesis
    private func buildUserPrompt(
        from usable: [(block: RecognizedBlock, role: BlockRole)]
    ) -> String {
        let separator = String(repeating: "─", count: 60)
        var lines = [
            "CONTENIDO DEL PIZARRÓN (ordenado por posición de lectura):",
            "Formato: [ROL | orden:N | y_norm:F | alto_norm:F | confianza:F%] texto",
            separator
        ]

        for (block, role) in usable {
            let y    = String(format: "%.3f", block.boundingBox.origin.y)
            let h    = String(format: "%.3f", block.boundingBox.height)
            let conf = String(format: "%.0f%%", block.confidence * 100)
            lines.append("[\(role.rawValue) | orden:\(block.readingOrder) | y_norm:\(y) | alto_norm:\(h) | confianza:\(conf)] \(block.text)")
        }

        lines += [
            separator,
            "Analiza el contenido y devuelve el JSON de StructuredContent. " +
            "Agrupa los bloques CUERPO bajo el SUBTITULO más cercano que los preceda. " +
            "Si no hay SUBTITULO previo, usa el TITULO_PRINCIPAL como título de sección."
        ]

        return lines.joined(separator: "\n")
    }

    // MARK: - Paso 3: Llamada a Foundation Models

    private func callFoundationModel(system: String, user: String) async throws -> String {
        let model = SystemLanguageModel.default
        guard model.availability == .available else {
            throw FoundationModelsError.modelUnavailable
        }

        // `instructions:` es el parámetro correcto para el system prompt en iOS 26.
        let session  = LanguageModelSession(instructions: system)
        let response = try await session.respond(to: user)
        return response.content
    }

    // MARK: - Paso 4: Decodificación vía DTO

    private func decodeResponse(_ raw: String, metadata: ProcessingMetadata) throws -> StructuredContent {
        // Limpieza defensiva: el modelo puede envolver JSON en ```json … ```
        // aunque el prompt lo prohíbe.
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = cleaned.data(using: .utf8) else {
            throw FoundationModelsError.invalidJSONResponse(raw)
        }

        // DTO intermedio: el LLM no conoce processingMetadata, lo añadimos nosotros.
        // Si usáramos StructuredContent directamente, el decoder fallaría por la
        // clave faltante.
        do {
            let dto = try JSONDecoder().decode(StructuredContentDTO.self, from: data)
            return StructuredContent(
                mainTitle:          dto.mainTitle,
                summary:            dto.summary,
                sections:           dto.sections,
                keyConcepts:        dto.keyConcepts,
                mathFound:          dto.mathFound,
                processingMetadata: metadata
            )
        } catch {
            throw FoundationModelsError.decodingFailed(error)
        }
    }

    // MARK: - Paso 5: Tiempo de procesamiento

    // Nota: sin `inout` — construimos un nuevo valor en lugar de mutar uno existente.
    // StructuredContent es un struct (valor), así que la copia es barata y explícita.
    private func patchProcessingTime(_ content: StructuredContent, start: Date) -> StructuredContent {
        let ms = Date().timeIntervalSince(start) * 1000
        let meta = ProcessingMetadata(
            totalBlocksReceived: content.processingMetadata.totalBlocksReceived,
            blocksDiscarded:     content.processingMetadata.blocksDiscarded,
            blocksFlagged:       content.processingMetadata.blocksFlagged,
            discardThreshold:    content.processingMetadata.discardThreshold,
            processingTimeMs:    ms
        )
        return StructuredContent(
            mainTitle:          content.mainTitle,
            summary:            content.summary,
            sections:           content.sections,
            keyConcepts:        content.keyConcepts,
            mathFound:          content.mathFound,
            processingMetadata: meta
        )
    }
}

// MARK: - DTO interno para decodificación

/// Subconjunto de StructuredContent que el LLM puede generar.
/// Excluye processingMetadata, que añadimos nosotros en el paso 4.
private struct StructuredContentDTO: Decodable {
    let mainTitle:   String
    let summary:     String
    let sections:    [Section]
    let keyConcepts: [String]
    let mathFound:   [String]?
}
