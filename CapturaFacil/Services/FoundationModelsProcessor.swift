// MARK: - FoundationModelsProcessor.swift
// Capa de Comprensión: transforma [RecognizedBlock] → Capture
// usando el modelo de lenguaje on-device de Apple (Foundation Models, iOS 26+).
//
// Decisión de diseño v3:
//   El procesador devuelve directamente un `Capture` en lugar de un
//   `StructuredContent` intermedio. Esto elimina los tipos huérfanos
//   `Section`, `ProcessingMetadata` y `StructuredContent` que no existían
//   en Models.swift, causando que el cast `rawResult as? StructuredContent`
//   fallara silenciosamente y CaptureService siempre usara el fallback
//   de texto crudo sin procesar.
//
// Pipeline:
//   [RecognizedBlock]
//     ├─ 1. Filtrado por confidence + clasificación multi-señal de títulos
//     ├─ 2. Serialización del prompt con contexto espacial y titleScore
//     ├─ 3. LanguageModelSession (on-device, sin red)
//     ├─ 4. Decodificación JSON → CaptureDTO (privado, no sale del archivo)
//     └─ 5. Mapeo CaptureDTO → Capture (tipo del dominio del proyecto)

import Foundation
import FoundationModels
import CoreGraphics
import UIKit

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
            return "Respuesta JSON inválida: \(raw.prefix(120))…"
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

// MARK: - DTOs de decodificación (todos privados, no salen del archivo)

private struct StepDTO: Decodable {
    let number:      Int
    let description: String
    let expression:  String
}

private struct FormulaDTO: Decodable {
    let rawText: String
    let steps:   [StepDTO]
}

private struct SectionDTO: Decodable {
    let title:   String
    let bullets: [String]
}

private struct CaptureDTO: Decodable {
    let mainTitle:   String
    let summary:     String
    let sections:    [SectionDTO]
    let keyConcepts: [String]
    let mathFound:   [FormulaDTO]?
}

// MARK: - Procesador principal

final class FoundationModelsProcessor: InformationProcessor {

    // MARK: Umbrales configurables

    var discardThreshold:  Float   = 0.30
    var dubiousThreshold:  Float   = 0.50
    var h1HeightThreshold: CGFloat = 0.06
    var h2HeightThreshold: CGFloat = 0.035

    // MARK: - InformationProcessor
    // Devuelve `Capture` directamente. CaptureService castea a `Capture`,
    // que siempre está disponible — sin riesgo de fallo silencioso.

    func process(blocks: [RecognizedBlock]) async throws -> any Sendable {
        let (usable, _, _) = filterAndClassify(blocks)
        guard !usable.isEmpty else { throw FoundationModelsError.allBlocksDiscarded }

        let rawJSON = try await callFoundationModel(
            system: buildSystemPrompt(),
            user:   buildUserPrompt(from: usable, totalBlocks: blocks.count)
        )

        return try buildCapture(from: rawJSON)
    }

    // MARK: - Paso 1: Filtrado y clasificación multi-señal

    private func filterAndClassify(
        _ blocks: [RecognizedBlock]
    ) -> (usable: [(block: RecognizedBlock, role: BlockRole)], discarded: Int, flagged: Int) {

        var discarded = 0
        var flagged   = 0
        var usable:   [(block: RecognizedBlock, role: BlockRole)] = []

        let sorted     = blocks.sorted { $0.readingOrder < $1.readingOrder }
        let maxHeight  = sorted.map(\.boundingBox.height).max() ?? 1
        let meanHeight: CGFloat = sorted.isEmpty
            ? 1
            : sorted.map(\.boundingBox.height).reduce(0, +) / CGFloat(sorted.count)

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
        return (usable, discarded, flagged)
    }

    // MARK: - Clasificación multi-señal de títulos
    //
    // Acumula puntos de 7 señales independientes:
    //   1. Altura relativa al máximo del conjunto  (hasta +4)
    //   2. Altura absoluta normalizada (Vision)    (hasta +3)
    //   3. Posición Y alta en la imagen             (hasta +2)
    //   4. Centrado horizontal (xCenter ≈ 0.5)     (hasta +2)
    //   5. Primer bloque en orden de lectura        (+2)
    //   6. Longitud del texto (corto = encabezado)  (hasta +2, hasta -2)
    //   7. Patrones textuales (MAYÚS, termina en :) (hasta +3)
    //
    // Umbral: ≥7 → H1 | 4–6 → H2 | <4 → CUERPO

    private func semanticRole(
        for block: RecognizedBlock,
        maxHeight: CGFloat,
        meanHeight: CGFloat,
        isFirstBlock: Bool
    ) -> BlockRole {

        var score = 0
        let bb    = block.boundingBox
        let text  = block.text.trimmingCharacters(in: .whitespaces)

        // 1. Altura relativa
        let hr = maxHeight > 0 ? bb.height / maxHeight : 0
        if hr >= 0.90      { score += 4 }
        else if hr >= 0.70 { score += 2 }

        // 2. Altura absoluta
        if bb.height >= h1HeightThreshold      { score += 3 }
        else if bb.height >= h2HeightThreshold { score += 1 }

        // 3. Posición Y (Vision: origen inferior-izquierdo → mayor Y = más arriba)
        let topEdge = bb.origin.y + bb.height
        if topEdge >= 0.80      { score += 2 }
        else if topEdge >= 0.65 { score += 1 }

        // 4. Centrado horizontal
        let xc = bb.origin.x + bb.width / 2
        let distFromCenter = abs(xc - 0.5)
        if distFromCenter <= 0.12      { score += 2 }
        else if distFromCenter <= 0.20 { score += 1 }

        // 5. Primer bloque
        if isFirstBlock { score += 2 }

        // 6. Longitud del texto
        let wc = text.split(separator: " ").count
        if wc <= 4       { score += 2 }
        else if wc <= 7  { score += 1 }
        else if wc >= 20 { score -= 2 }

        // 7. Patrones textuales
        if text == text.uppercased() && text.count > 2 { score += 2 }
        if text.hasSuffix(":")                          { score += 1 }

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
        de notas de clase, pizarrones o presentaciones, con su posición espacial, rol \
        semántico y puntuación de título (titleScore).

        REGLAS OBLIGATORIAS:
        1. JERARQUÍA: Usa los roles TITULO_PRINCIPAL y SUBTITULO para identificar \
           estructura. Si ningún bloque tiene TITULO_PRINCIPAL pero hay uno con \
           titleScore alto, úsalo como título. Si todos los scores son bajos, \
           infiere el título del contexto semántico.
        2. SIMPLIFICACIÓN: Reescribe el CUERPO en lenguaje claro y digerible. \
           Conserva ÍNTEGRA la terminología técnica y científica.
        3. MATEMÁTICAS: Extrae TODAS las fórmulas y ecuaciones a `mathFound`. \
           Para cada una genera entre 2 y 6 pasos explicativos. Si la fórmula \
           es una definición, describe sus componentes como pasos. Sin matemáticas, \
           omite completamente el campo `mathFound` del JSON.
        4. DUDOSOS: Usa bloques DUDOSO solo si aportan contexto claro.
        5. RESUMEN: `summary` debe ser EXACTAMENTE 2 oraciones.
        6. CONCEPTOS: Entre 3 y 7 términos clave en `keyConcepts`.
        7. SALIDA: ÚNICAMENTE el objeto JSON. Sin markdown ni texto adicional.

        ESQUEMA JSON (claves exactas, respeta los tipos):
        {
          "mainTitle": "string",
          "summary": "string (2 oraciones exactas)",
          "sections": [
            { "title": "string", "bullets": ["string"] }
          ],
          "keyConcepts": ["string"],
          "mathFound": [
            {
              "rawText": "string",
              "steps": [
                { "number": 1, "description": "string", "expression": "string" }
              ]
            }
          ]
        }
        """
    }

    // MARK: - Paso 2b: User prompt con contexto espacial y titleScore

    private func buildUserPrompt(
        from usable: [(block: RecognizedBlock, role: BlockRole)],
        totalBlocks: Int
    ) -> String {
        let sep  = String(repeating: "─", count: 60)
        let maxH = usable.map { $0.block.boundingBox.height }.max() ?? 1

        var lines = [
            "CONTENIDO (\(usable.count) de \(totalBlocks) bloques, ordenado por posición de lectura):",
            "Formato: [ROL | orden:N | y_norm:F | alto_norm:F | xCenter:F | titleScore:N | conf:F%] texto",
            sep
        ]

        for (block, role) in usable {
            let bb   = block.boundingBox
            let y    = String(format: "%.3f", bb.origin.y)
            let h    = String(format: "%.3f", bb.height)
            let xc   = String(format: "%.3f", bb.origin.x + bb.width / 2)
            let conf = String(format: "%.0f%%", block.confidence * 100)
            let sc   = computeTitleScore(block: block, maxHeight: maxH)
            lines.append(
                "[\(role.rawValue) | orden:\(block.readingOrder) | y_norm:\(y) | alto_norm:\(h) | xCenter:\(xc) | titleScore:\(sc) | conf:\(conf)] \(block.text)"
            )
        }

        lines += [
            sep,
            "Devuelve el JSON. Agrupa bloques CUERPO bajo su SUBTITULO precedente.",
            "Para mathFound, genera pasos que expliquen cómo resolver o interpretar cada componente."
        ]
        return lines.joined(separator: "\n")
    }

    private func computeTitleScore(block: RecognizedBlock, maxHeight: CGFloat) -> Int {
        var score = 0
        let bb    = block.boundingBox
        let text  = block.text.trimmingCharacters(in: .whitespaces)

        let hr = maxHeight > 0 ? bb.height / maxHeight : 0
        if hr >= 0.90 { score += 4 } else if hr >= 0.70 { score += 2 }

        if bb.height >= h1HeightThreshold       { score += 3 }
        else if bb.height >= h2HeightThreshold  { score += 1 }

        let topEdge = bb.origin.y + bb.height
        if topEdge >= 0.80 { score += 2 } else if topEdge >= 0.65 { score += 1 }

        let xc = bb.origin.x + bb.width / 2
        if abs(xc - 0.5) <= 0.12 { score += 2 } else if abs(xc - 0.5) <= 0.20 { score += 1 }

        let wc = text.split(separator: " ").count
        if wc <= 4 { score += 2 } else if wc <= 7 { score += 1 } else if wc >= 20 { score -= 2 }

        if text == text.uppercased() && text.count > 2 { score += 2 }
        if text.hasSuffix(":") { score += 1 }

        return max(0, score)
    }

    // MARK: - Paso 3: Llamada a Foundation Models

    private func callFoundationModel(system: String, user: String) async throws -> String {
        guard SystemLanguageModel.default.availability == .available else {
            throw FoundationModelsError.modelUnavailable
        }
        let session  = LanguageModelSession(instructions: system)
        let response = try await session.respond(to: user)
        #if DEBUG
        print("[FoundationModelsProcessor] RAW JSON from model →\n\n\(response.content)\n\n—— END RAW ——")
        #endif
        return response.content
    }

    // MARK: - Paso 4+5: Decodificación JSON → Capture

    private func buildCapture(from raw: String) throws -> Capture {
        // Limpieza defensiva: el modelo puede envolver el JSON en ```json … ```
        let cleaned = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```",     with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        #if DEBUG
        print("[FoundationModelsProcessor] CLEANED JSON to decode →\n\n\(cleaned)\n\n—— END CLEANED ——")
        #endif

        guard let data = cleaned.data(using: .utf8) else {
            throw FoundationModelsError.invalidJSONResponse(raw)
        }

        let dto: CaptureDTO
        do {
            dto = try JSONDecoder().decode(CaptureDTO.self, from: data)
        } catch {
            throw FoundationModelsError.decodingFailed(error)
        }

        // ── Fórmulas con pasos ────────────────────────────────────────────────
        let formulas: [MathFormula] = (dto.mathFound ?? []).map { f in
            MathFormula(
                rawText: f.rawText,
                steps: f.steps.map { s in
                    SolutionStep(
                        number:      s.number,
                        description: s.description,
                        expression:  s.expression
                    )
                }
            )
        }

        // ── Texto extraído formateado ─────────────────────────────────────────
        var textParts = [dto.summary]
        for section in dto.sections {
            textParts.append("\n\(section.title)")
            textParts.append(contentsOf: section.bullets.map { "• \($0)" })
        }
        if !dto.keyConcepts.isEmpty {
            textParts.append("\nConceptos clave: \(dto.keyConcepts.joined(separator: ", "))")
        }

        // ── Bloques de explicación ────────────────────────────────────────────
        var explanations = [
            ExplanationBlock(
                title:      "Idea Central",
                body:       dto.summary,
                isCoreIdea: true
            )
        ]
        for (i, section) in dto.sections.enumerated() {
            explanations.append(ExplanationBlock(
                number:     i + 1,
                title:      section.title,
                body:       section.bullets.joined(separator: "\n"),
                isCoreIdea: false
            ))
        }

        return Capture(
            title:            dto.mainTitle,
            extractedText:    textParts.joined(separator: "\n"),
            detectedFormulas: formulas,
            explanations:     explanations
        )
    }
}

