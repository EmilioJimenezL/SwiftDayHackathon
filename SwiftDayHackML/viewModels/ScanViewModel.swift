// MARK: - ScanViewModel.swift
// Capa de coordinación: orquesta el flujo entre la UI y los servicios.
//
// Decisión de diseño: El ViewModel recibe el `OCRProcessing` por inyección de
// dependencias (no lo instancia él mismo). Esto tiene dos ventajas concretas:
//  1. Testabilidad: los tests unitarios pasan un `MockOCRProcessor` sin Vision.
//  2. Extensibilidad: cuando se agregue el InformationProcessor de Foundation Models,
//     se inyecta de la misma forma sin modificar el ViewModel existente.

import SwiftUI
import Combine

@MainActor
final class ScanViewModel: ObservableObject {

    // MARK: - Estado de la UI
    @Published var selectedImage: UIImage?
    @Published var recognizedBlocks: [RecognizedBlock] = []
    @Published var isProcessing: Bool = false
    @Published var errorMessage: String?
    @Published var showImagePicker: Bool = false
    @Published var imagePickerSource: UIImagePickerController.SourceType = .photoLibrary

    // MARK: - Dependencias inyectadas
    private let ocrProcessor: OCRProcessing

    /// `informationProcessor` es opcional para esta fase.
    /// Cuando Foundation Models esté listo, se inyecta aquí y se invoca
    /// después de `ocrProcessor.recognize(image:)`.
    var informationProcessor: (any InformationProcessor)?

    // MARK: - Stats de sesión (útiles para debug y métricas del hackathon)
    @Published private(set) var processingTimeMs: Double = 0
    @Published private(set) var averageConfidence: Float = 0

    // @MainActor no puede llamar OCRProcessor() directamente en un default param
    // porque el init de OCRProcessor no está aislado al actor principal.
    // Solución: un init designado que acepta el protocolo, y un segundo init
    // sin argumentos que construye el default explícitamente.
    init(ocrProcessor: OCRProcessing) {
        self.ocrProcessor = ocrProcessor
    }

    /// Init de conveniencia para el caso más común (sin inyección de dependencias).
    /// Al declararlo como `nonisolated`, Swift puede instanciar OCRProcessor()
    /// fuera del contexto del MainActor y luego transferir el objeto.
    nonisolated init() {
        self.ocrProcessor = OCRProcessor()
    }

    // MARK: - Acciones públicas (llamadas desde la View)

    func selectPhoto(from source: UIImagePickerController.SourceType) {
        imagePickerSource = source
        showImagePicker = true
    }

    /// Punto de entrada principal. Se llama cuando el usuario confirma la imagen.
    func processImage(_ image: UIImage) {
        selectedImage = image
        recognizedBlocks = []
        errorMessage = nil

        Task {
            await runOCR(on: image)
        }
    }

    func clearResults() {
        selectedImage = nil
        recognizedBlocks = []
        errorMessage = nil
        processingTimeMs = 0
        averageConfidence = 0
    }

    // MARK: - Pipeline interno

    private func runOCR(on image: UIImage) async {
        isProcessing = true
        let start = Date()

        do {
            let blocks = try await ocrProcessor.recognize(image: image)
            recognizedBlocks = blocks
            processingTimeMs = Date().timeIntervalSince(start) * 1000
            averageConfidence = blocks.isEmpty ? 0 : blocks.map(\.confidence).reduce(0, +) / Float(blocks.count)

            // MARK: Gancho para la siguiente fase (Foundation Models)
            // Cuando `informationProcessor` esté disponible, el texto ya estructurado
            // fluirá automáticamente sin cambiar nada del código anterior.
            if let processor = informationProcessor {
                _ = try await processor.process(blocks: blocks)
                // TODO: recibir StructuredDocument y publicarlo en @Published
            }

        } catch {
            errorMessage = error.localizedDescription
        }

        isProcessing = false
    }

    // MARK: - Helpers para la vista

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
