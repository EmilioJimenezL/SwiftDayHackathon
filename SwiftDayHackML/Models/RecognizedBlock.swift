// MARK: - RecognizedBlock.swift
// Modelo de datos de la Capa de Percepción (Fase 1).
//
// Decisión de diseño: capturamos más que el String porque la geometría
// (boundingBox) es una señal estructural valiosa para la Fase 2.
// Un bloque en la parte superior de la imagen con altura grande probablemente
// es un título, sin necesidad de un modelo de lenguaje. Conservar el
// `confidence` permite filtrar o ponderar resultados en fases posteriores.

import Foundation
import CoreGraphics

/// Bloque de texto detectado por Vision Framework con todos sus metadatos.
struct RecognizedBlock: Identifiable {

    /// UUID generado por nosotros — permite identificar el bloque en listas
    /// SwiftUI y correlacionarlo si se enriquece con etiquetas semánticas.
    let id: UUID

    /// Texto transcrito por el motor OCR.
    let text: String

    /// Rectángulo normalizado [0,1] en coordenadas Vision (origen inferior-izquierdo).
    /// Se convierte a coordenadas UIKit/SwiftUI (origen superior-izquierdo) en
    /// BoundingBoxOverlay antes de dibujarse.
    let boundingBox: CGRect

    /// Score de confianza de Vision (0.0 → 1.0).
    let confidence: Float

    /// Índice de orden de lectura calculado por posición Y descendente en OCRProcessor.
    let readingOrder: Int

    // MARK: - Helpers de presentación

    var confidencePercent: String {
        String(format: "%.1f%%", confidence * 100)
    }

    var boundingBoxDescription: String {
        String(
            format: "x:%.3f y:%.3f w:%.3f h:%.3f",
            boundingBox.origin.x,
            boundingBox.origin.y,
            boundingBox.width,
            boundingBox.height
        )
    }
}

// MARK: - InformationProcessor Protocol
//
// Contrato entre la Capa de Percepción y la Capa de Comprensión.
// El tipo de retorno `any Sendable` desacopla el protocolo de cualquier
// tipo de salida concreto — FoundationModelsProcessor devuelve StructuredContent,
// pero un procesador futuro podría devolver un tipo diferente sin cambiar
// la firma del protocolo ni el ViewModel.

protocol InformationProcessor {
    func process(blocks: [RecognizedBlock]) async throws -> any Sendable
}
