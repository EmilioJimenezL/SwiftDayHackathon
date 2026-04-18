// MARK: - StructuredContent.swift
// Modelo de salida de la Capa de Comprensión (Fase 2).
//
// Decisión de diseño: separado de RecognizedBlock deliberadamente.
// RecognizedBlock es "qué percibió Vision" — datos crudos con coordenadas.
// StructuredContent es "qué significa el pizarrón" — semántica lista para
// renderizar en la UI de accesibilidad.

import Foundation

// MARK: - Modelo principal

/// Representación semántica completa de un pizarrón o documento.
/// Conforma Codable para facilitar caché local y logging de sesiones de prueba.
struct StructuredContent: Codable, Sendable {

    /// Título principal. Deriva del bloque con mayor altura de fuente en posición superior.
    let mainTitle: String

    /// Resumen ejecutivo de exactamente 2 oraciones generado por el modelo.
    /// Se muestra primero en la UI para reducir carga cognitiva antes de leer el contenido.
    let summary: String

    /// Secciones del contenido, cada una con título, viñetas y confianza agregada.
    let sections: [Section]

    /// Conceptos clave (3–7 términos). Se renderizan como chips táctiles.
    let keyConcepts: [String]

    /// Fórmulas matemáticas separadas del flujo de texto.
    /// `nil` si no hay matemáticas — evita renders vacíos en la UI.
    let mathFound: [String]?

    /// Metadatos del proceso para trazabilidad y debug.
    let processingMetadata: ProcessingMetadata
}

// MARK: - Sección

struct Section: Codable, Sendable {

    /// Encabezado de la sección.
    let title: String

    /// Contenido reformulado en lenguaje simple. Terminología técnica se conserva intacta.
    let bullets: [String]

    /// Confianza promedio de los bloques OCR que componen esta sección.
    /// La UI puede usar este valor para mostrar un indicador visual de fiabilidad.
    let confidenceLevel: Float
}

// MARK: - Metadatos de procesamiento

struct ProcessingMetadata: Codable, Sendable {
    let totalBlocksReceived: Int
    let blocksDiscarded: Int
    let blocksFlagged: Int
    let discardThreshold: Float
    var processingTimeMs: Double
}
