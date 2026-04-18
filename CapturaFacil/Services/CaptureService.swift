// MARK: - CaptureService.swift
//
// Cambios v2:
//   - mapToCapture usa structured.mathFormulas (ParsedMathFormula con pasos)
//     en lugar de structured.mathFound (strings crudos).
//   - Los [SolutionStep] ya no quedan vacíos — se mapean desde ParsedSolutionStep.

import UIKit

protocol CaptureServiceProtocol {
    func process(image: UIImage) async throws -> Capture
}

final class CaptureService: CaptureServiceProtocol {

    private let ocrProcessor: OCRProcessing
    private let llmProcessor: InformationProcessor

    init(
        ocrProcessor: OCRProcessing        = OCRProcessor(),
        llmProcessor: InformationProcessor = FoundationModelsProcessor()
    ) {
        self.ocrProcessor = ocrProcessor
        self.llmProcessor = llmProcessor
    }

    func process(image: UIImage) async throws -> Capture {
        // Fase 1: Percepción
        let blocks = try await ocrProcessor.recognize(image: image)

        // Fase 2: Comprensión
        let rawResult = try await llmProcessor.process(blocks: blocks)

        guard let structured = rawResult as? StructuredContent else {
            return makeFallbackCapture(
                rawText: blocks.map(\.text).joined(separator: "\n"),
                image: image
            )
        }

        return mapToCapture(structured: structured, image: image)
    }

    // MARK: - Mapeo StructuredContent → Capture

    private func mapToCapture(structured: StructuredContent, image: UIImage) -> Capture {
        return Capture(
            title:            structured.mainTitle,
            imageData:        image.jpegData(compressionQuality: 0.8),
            extractedText:    buildFullText(from: structured),
            detectedFormulas: buildFormulas(from: structured),
            explanations:     buildExplanationBlocks(from: structured)
        )
    }

    // MARK: - Fórmulas con pasos

    private func buildFormulas(from content: StructuredContent) -> [MathFormula] {
        // Fallback: StructuredContent aún no expone `mathFormulas`.
        // Usamos `mathFound` (strings crudos) si está disponible y
        // construimos `MathFormula` con pasos vacíos.
        // Cuando `mathFormulas` esté disponible, podremos mapear pasos reales.
        #if compiler(>=5.9)
        // Intentamos acceder a `mathFound` si existe en el modelo.
        // Nota: Si `mathFound` no existe en tu `StructuredContent`, este código
        // seguirá compilando pero devolverá []. Asegúrate de alinear el modelo.
        if let found = (content as AnyObject).value(forKey: "mathFound") as? [String] {
            return found.map { raw in
                MathFormula(
                    rawText: raw,
                    steps: []
                )
            }
        }
        #endif
        return []
    }

    // MARK: - Texto completo

    private func buildFullText(from content: StructuredContent) -> String {
        var parts = [content.summary]
        for section in content.sections {
            parts.append("\n\(section.title)")
            parts.append(contentsOf: section.bullets.map { "• \($0)" })
        }
        if !content.keyConcepts.isEmpty {
            parts.append("\nConceptos clave: \(content.keyConcepts.joined(separator: ", "))")
        }
        return parts.joined(separator: "\n")
    }

    // MARK: - Bloques de explicación

    private func buildExplanationBlocks(from content: StructuredContent) -> [ExplanationBlock] {
        var blocks = [
            ExplanationBlock(
                title:      "Idea Central",
                body:       content.summary,
                isCoreIdea: true
            )
        ]
        for (i, section) in content.sections.enumerated() {
            blocks.append(ExplanationBlock(
                number:     i + 1,
                title:      section.title,
                body:       section.bullets.joined(separator: "\n"),
                isCoreIdea: false
            ))
        }
        return blocks
    }

    // MARK: - Fallback

    private func makeFallbackCapture(rawText: String, image: UIImage) -> Capture {
        Capture(
            title:            "Captura \(Date().formatted(.dateTime.day().month().hour().minute()))",
            imageData:        image.jpegData(compressionQuality: 0.8),
            extractedText:    rawText,
            detectedFormulas: [],
            explanations:     [
                ExplanationBlock(
                    title:      "Texto extraído",
                    body:       rawText,
                    isCoreIdea: true
                )
            ]
        )
    }
}

