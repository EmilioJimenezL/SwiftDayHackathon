//
//  CaptureService.swift
//  CapturaFacil
//
//  Created by Rafael on 18/04/26.
//

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
            return makeFallbackCapture(rawText: blocks.map(\.text).joined(separator: "\n"), image: image)
        }

        return mapToCapture(structured: structured, image: image)
    }

    // MARK: - Mapeo StructuredContent → Capture

    private func mapToCapture(structured: StructuredContent, image: UIImage) -> Capture {
        let formulas = (structured.mathFound ?? []).map { MathFormula(rawText: $0, steps: []) }
        return Capture(
            title:            structured.mainTitle,
            imageData:        image.jpegData(compressionQuality: 0.8),
            extractedText:    buildFullText(from: structured),
            detectedFormulas: formulas,
            explanations:     buildExplanationBlocks(from: structured)
        )
    }

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

    private func buildExplanationBlocks(from content: StructuredContent) -> [ExplanationBlock] {
        var blocks = [ExplanationBlock(title: "Idea Central", body: content.summary, isCoreIdea: true)]
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

    private func makeFallbackCapture(rawText: String, image: UIImage) -> Capture {
        Capture(
            title:            "Captura \(Date().formatted(.dateTime.day().month().hour().minute()))",
            imageData:        image.jpegData(compressionQuality: 0.8),
            extractedText:    rawText,
            detectedFormulas: [],
            explanations:     [ExplanationBlock(title: "Texto extraído", body: rawText, isCoreIdea: true)]
        )
    }
}
