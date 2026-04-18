// MARK: - OCRProcessor.swift
// Capa de Percepción: encapsula todo lo relacionado con Vision Framework.
//
// Decisión de diseño: clase final sin dependencias de UI, fácil de testear
// e inyectar. El protocolo `OCRProcessing` permite sustituirlo por un mock
// en pruebas o por un motor alternativo sin tocar el ViewModel.

import Vision
import UIKit

// MARK: - Errores

enum OCRError: LocalizedError {
    case invalidImage
    case noTextFound
    case visionFailure(Error)

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "No se pudo crear un CIImage a partir de la imagen proporcionada."
        case .noTextFound:
            return "Vision no detectó texto en la imagen."
        case .visionFailure(let e):
            return "Error de Vision: \(e.localizedDescription)"
        }
    }
}

// MARK: - Protocolo

protocol OCRProcessing {
    func recognize(image: UIImage) async throws -> [RecognizedBlock]
}

// MARK: - Implementación

final class OCRProcessor: OCRProcessing {

    var recognitionLevel: VNRequestTextRecognitionLevel = .accurate
    var recognitionLanguages: [String] = ["es-MX", "es", "en-US"]
    var minimumTextHeight: Float = 0.015
    var usesLanguageCorrection: Bool = true

    func recognize(image: UIImage) async throws -> [RecognizedBlock] {
        guard let ciImage = CIImage(image: image) else {
            throw OCRError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = buildRequest { result in
                switch result {
                case .success(let blocks): continuation.resume(returning: blocks)
                case .failure(let error):  continuation.resume(throwing: error)
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

    // MARK: - Privado

    private func buildRequest(
        completion: @escaping (Result<[RecognizedBlock], Error>) -> Void
    ) -> VNRecognizeTextRequest {

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

            completion(.success(buildBlocks(from: observations)))
        }

        request.recognitionLevel       = recognitionLevel
        request.recognitionLanguages   = recognitionLanguages
        request.minimumTextHeight      = minimumTextHeight
        request.usesLanguageCorrection = usesLanguageCorrection
        return request
    }

    private func buildBlocks(from observations: [VNRecognizedTextObservation]) -> [RecognizedBlock] {
        // Mayor Y en Vision = más arriba en la imagen = primero en orden de lectura.
        let sorted = observations.sorted { $0.boundingBox.minY > $1.boundingBox.minY }

        return sorted.enumerated().compactMap { index, observation in
            guard let candidate = observation.topCandidates(1).first else { return nil }
            return RecognizedBlock(
                id: UUID(),
                text: candidate.string,
                boundingBox: observation.boundingBox,
                confidence: candidate.confidence,
                readingOrder: index
            )
        }
    }
}
