// MARK: - CaptureService.swift
//
// Cambios v3:
//   FoundationModelsProcessor ahora devuelve `Capture` directamente,
//   eliminando la necesidad de mapear StructuredContent → Capture aquí.
//   CaptureService conserva su responsabilidad de orquestar el pipeline
//   y construir el fallback, pero el mapeo de datos vive en el procesador.

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
        // Fase 1: Percepción — Vision Framework extrae bloques con metadatos
        let blocks = try await ocrProcessor.recognize(image: image)

        // Fase 2: Comprensión — Foundation Models devuelve Capture ya construido
        let rawResult = try await llmProcessor.process(blocks: blocks)

        // El cast a Capture ahora siempre funciona porque FoundationModelsProcessor
        // construye y devuelve un Capture real, no un tipo intermedio huérfano.
        guard let capture = rawResult as? Capture else {
            // Fallback defensivo: si por alguna razón el cast falla (p.ej. al
            // usar un InformationProcessor alternativo en tests), devolvemos
            // el texto OCR crudo formateado como Capture mínimo.
            return makeFallbackCapture(
                rawText: blocks.map(\.text).joined(separator: "\n"),
                image:   image
            )
        }

        // Adjuntamos la imagen al Capture construido por el procesador.
        // El procesador no recibe UIImage, así que no puede incluirla.
        return Capture(
            id:               capture.id,
            title:            capture.title,
            timestamp:        capture.timestamp,
            imageData:        image.jpegData(compressionQuality: 0.8),
            extractedText:    capture.extractedText,
            detectedFormulas: capture.detectedFormulas,
            explanations:     capture.explanations
        )
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
