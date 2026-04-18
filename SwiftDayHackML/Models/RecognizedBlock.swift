// MARK: - RecognizedBlock.swift
// Modelo de datos central de la Capa de Percepción.
//
// Decisión de diseño: Capturamos más que solo el String porque la geometría
// (boundingBox) es una señal estructural valiosa para la siguiente fase de ML.
// Un bloque en la parte superior de la imagen con altura grande probablemente
// es un título, sin necesidad de un modelo de lenguaje. Conservar el
// `confidence` nos permite filtrar o ponderar resultados en fases posteriores.

import Foundation
import CoreGraphics

/// Representa un bloque de texto detectado por Vision Framework,
/// con todos los metadatos necesarios para las fases de estructuración e interpretación.
struct RecognizedBlock: Identifiable {

    /// UUID generado por nosotros — permite identificar el bloque en listas SwiftUI
    /// y correlacionarlo si se enriquece con etiquetas semánticas más adelante.
    let id: UUID

    /// Texto transcrito por el motor OCR.
    let text: String

    /// Rectángulo normalizado [0,1] en coordenadas Vision (origen inferior-izquierdo).
    /// Se convierte a coordenadas UIKit (origen superior-izquierdo) antes de mostrarse.
    /// Este campo es la entrada principal para la heurística geométrica de clasificación.
    let boundingBox: CGRect

    /// Score de confianza de Vision (0.0 → 1.0).
    /// Usamos Float por ser el tipo nativo de VNRecognizedText.confidence.
    let confidence: Float

    /// Índice de orden de lectura inferido por posición vertical.
    /// Se calcula en el servicio para mantener el modelo "tonto" (sin lógica).
    let readingOrder: Int

    // MARK: - Computed helpers para la vista de debug

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
// Contrato que define cualquier procesador que reciba el texto ya extraído.
// Actualmente no hay implementación concreta de ML/LLM, pero el ViewModel
// ya acepta cualquier tipo que conforme a este protocolo, lo que hace la
// inyección de dependencias trivial en la siguiente fase.
//
// Siguiente paso esperado: crear `FoundationModelsProcessor: InformationProcessor`
// que tome los bloques, los ordene por `readingOrder` y llame a la API de
// Foundation Models para etiquetar título / subtítulo / cuerpo / fórmula.
protocol InformationProcessor {
    /// Procesa los bloques extraídos y devuelve un resultado semántico enriquecido.
    /// El tipo de retorno es genérico (any Sendable) para no acoplar el protocolo
    /// a ninguna estructura de datos específica de la Capa de Comprensión.
    func process(blocks: [RecognizedBlock]) async throws -> any Sendable
}
