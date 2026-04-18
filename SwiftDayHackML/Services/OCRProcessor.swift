// MARK: - OCRProcessor.swift
// Capa de Percepción: encapsula todo lo relacionado con Vision Framework.
//
// Decisión de diseño: Este servicio es una clase final sin dependencias de UI,
// lo que facilita escribir unit tests (se puede instanciar sin simulador) y
// inyectarlo en cualquier ViewModel futuro. El protocolo `OCRProcessing`
// permite sustituirlo por un mock en pruebas o por un motor alternativo.

import Vision
import UIKit

// MARK: - Errores del servicio OCR

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case visionFailure(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:       return "No se pudo crear un CIImage a partir de la imagen proporcionada."
        case .noTextFound:        return "Vision no detectó texto en la imagen."
        case .visionFailure(let e): return "Error de Vision: \(e.localizedDescription)"
        }
    }
}

// MARK: - Protocolo de abstracción
// Permite sustituir OCRProcessor por mocks en pruebas o por un motor diferente
// (ej. CoreML+CreateML con modelo fine-tuneado para pizarrones) sin tocar el ViewModel.
protocol OCRProcessing {
    func recognize(image: UIImage) async throws -> [RecognizedBlock]
}

// MARK: - Implementación con Vision Framework

final class OCRProcessor: OCRProcessing {

    // MARK: Configuración expuesta para ajuste externo
    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["es-MX", "es", "en-US"]
    var minimumTextHeight: Float = 0.015   // filtra ruido visual muy pequeño
    var usesLanguageCorrection: Bool = true

    // MARK: Proceso principal
    func recognize(image: UIImage) async throws -> [RecognizedBlock] {
        guard let ciImage = CIImage(image: image) else {
            throw OCRError.invalidImage
        }

        // Ejecutamos el handler de Vision en un contexto async para no bloquear el hilo principal.
        // Usamos withCheckedThrowingContinuation para "envolver" la API de completion-handler
        // de Vision en async/await — patrón idiomático desde Swift 5.5.
        return try await withCheckedThrowingContinuation { continuation in
            let request = buildRequest { result in
                switch result {
                case .success(let blocks):
                    continuation.resume(returning: blocks)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: OCRError.visionFailure(error))
            }
        }
    }

    // MARK: - Construcción del VNRecognizeTextRequest

    private func buildRequest(completion: @escaping (Result<[RecognizedBlock], Error>) -> Void) -> VNRecognizeTextRequest {

        let request = VNRecognizeTextRequest { [weak self] request, error in
            guard let self else { return }

            if let error {
                completion(.failure(OCRError.visionFailure(error)))
                return
            }

            guard let observations = request.results as? [VNRecognizedTextObservation],
                  !observations.isEmpty
            else {
                completion(.failure(OCRError.noTextFound))
                return
            }

            let blocks = self.buildBlocks(from: observations)
            completion(.success(blocks))
        }

        // .accurate usa el motor neural completo — más lento pero necesario
        // para escritura manual en pizarrón donde las letras no son perfectas.
        request.recognitionLevel = recognitionLevel
        request.recognitionLanguages = recognitionLanguages
        request.minimumTextHeight = minimumTextHeight
        request.usesLanguageCorrection = usesLanguageCorrection

        return request
    }

    // MARK: - Construcción de modelos de datos

    private func buildBlocks(from observations: [VNRecognizedTextObservation]) -> [RecognizedBlock] {
        // Ordenamos por posición Y descendente (Vision usa origen inferior-izquierdo,
        // así que mayor Y = más arriba en la imagen = primero en el orden de lectura).
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        return sorted.enumerated().compactMap { index, observation in
            // topCandidates(1) devuelve el resultado con mayor confidence.
            // Pedimos solo 1 porque en la Capa de Percepción queremos el mejor candidato;
            // en fases futuras se podrían pedir más para tener alternativas.
            guard let candidate = observation.topCandidates(1).first else { return nil }

            return RecognizedBlock(
                id: UUID(),
                text: candidate.string,
                boundingBox: observation.boundingBox,   // coordenadas normalizadas [0,1]
                confidence: candidate.confidence,
                readingOrder: index
            )
        }
    }
}
