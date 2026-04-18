// MARK: - ScanViewModel.swift
// Coordinador del pipeline de dos fases.
//
// Concurrencia (Swift 6):
//   No usamos @MainActor a nivel de clase para que los inits sean nonisolated
//   y @StateObject / @ObservedObject puedan instanciarlo sin warnings.
//   Cada método que muta @Published lleva @MainActor explícito.
//
// Inyección de dependencias:
//   OCRProcessor y FoundationModelsProcessor se inyectan desde LexiScanApp,
//   nunca se crean internamente en la View. Esto facilita tests y permite
//   swapear implementaciones (p.ej. MockInformationProcessor para demos).

import SwiftUI
import Combine

final class ScanViewModel: ObservableObject {

    // MARK: - Estado UI — Fase 1

    @Published var selectedImage: UIImage?
    @Published private(set) var recognizedBlocks: [RecognizedBlock] = []
    @Published private(set) var isProcessing: Bool = false
    @Published var showImagePicker: Bool = false
    @Published var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    // MARK: - Estado UI — Fase 2

    @Published private(set) var structuredContent: StructuredContent?
    @Published private(set) var isStructuring: Bool = false

    // MARK: - Estado compartido

    @Published private(set) var errorMessage: String?
    @Published private(set) var processingTimeMs: Double = 0
    @Published private(set) var averageConfidence: Float = 0

    // MARK: - Dependencias

    private let ocrProcessor: OCRProcessing

    /// Nil = solo Fase 1. Inyectado desde LexiScanApp.
    var informationProcessor: (any InformationProcessor)?

    // MARK: - Inits (nonisolated por defecto — requerido por @StateObject en Swift 6)

    init(ocrProcessor: OCRProcessing) {
        self.ocrProcessor = ocrProcessor
    }

    convenience init() {
        self.init(ocrProcessor: OCRProcessor())
    }

    // MARK: - API pública

    @MainActor
    func selectPhoto(from source: UIImagePickerController.SourceType) {
        imagePickerSource = source
        showImagePicker   = true
    }

    @MainActor
    func processImage(_ image: UIImage) {
        selectedImage    = image
        recognizedBlocks = []
        structuredContent = nil
        errorMessage     = nil
        Task { await runOCR(on: image) }
    }

    @MainActor
    func clearResults() {
        selectedImage     = nil
        recognizedBlocks  = []
        structuredContent = nil
        errorMessage      = nil
        processingTimeMs  = 0
        averageConfidence = 0
    }

    // MARK: - Pipeline interno

    @MainActor
    private func runOCR(on image: UIImage) async {
        isProcessing = true
        let start    = Date()

        do {
            let blocks = try await ocrProcessor.recognize(image: image)
            recognizedBlocks  = blocks
            processingTimeMs  = Date().timeIntervalSince(start) * 1000
            averageConfidence = blocks.isEmpty
                ? 0
                : blocks.map(\.confidence).reduce(0, +) / Float(blocks.count)

            if let processor = informationProcessor {
                await runStructuring(blocks: blocks, processor: processor)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    @MainActor
    private func runStructuring(
        blocks: [RecognizedBlock],
        processor: any InformationProcessor
    ) async {
        isStructuring = true
        do {
            let result = try await processor.process(blocks: blocks)
            if let content = result as? StructuredContent {
                structuredContent = content
            }
        } catch {
            // No sobreescribimos un error de OCR previo; concatenamos.
            let msg = "Estructuración: \(error.localizedDescription)"
            errorMessage = errorMessage.map { "\($0)\n\(msg)" } ?? msg
        }
        isStructuring = false
    }

    // MARK: - Helpers de solo lectura

    var fullExtractedText: String {
        recognizedBlocks
            .sorted { $0.readingOrder < $1.readingOrder }
            .map(\.text)
            .joined(separator: "\n")
    }

    var highConfidenceBlocks: [RecognizedBlock] {
        recognizedBlocks.filter { $0.confidence >= 0.7 }
    }

    var lowConfidenceBlocks: [RecognizedBlock] {
        recognizedBlocks.filter { $0.confidence < 0.7 }
    }
}
