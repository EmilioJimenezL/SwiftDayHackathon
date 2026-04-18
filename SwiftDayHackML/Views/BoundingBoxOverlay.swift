// MARK: - BoundingBoxOverlay.swift
// Overlay visual que dibuja los bounding boxes de Vision sobre la imagen.
//
// Decisión de diseño: Separamos este componente de la vista principal porque
// la lógica de transformación de coordenadas (Vision → UIKit → SwiftUI) es
// no trivial y merece estar aislada. También facilita reusarlo si en el futuro
// se añade un detector de diagramas o fórmulas matemáticas (discalculia).

import SwiftUI

struct BoundingBoxOverlay: View {
    let blocks: [RecognizedBlock]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ForEach(blocks) { block in
                let rect = transformedRect(
                    visionRect: block.boundingBox,
                    in: geometry.size
                )

                Rectangle()
                    .stroke(confidenceColor(block.confidence), lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(alignment: .topLeading) {
                        // Badge de confianza — útil para debug en el hackathon
                        Text(block.confidencePercent)
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 3)
                            .background(confidenceColor(block.confidence).opacity(0.85))
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                            .offset(x: rect.minX, y: rect.minY - 14)
                    }
            }
        }
    }

    // MARK: - Transformación de coordenadas
    //
    // Vision usa un sistema de coordenadas normalizado [0,1] con origen en la esquina
    // INFERIOR-IZQUIERDA. SwiftUI usa origen en la esquina SUPERIOR-IZQUIERDA.
    // La conversión es: y_swiftui = (1 - y_vision - height_vision)
    private func transformedRect(visionRect: CGRect, in containerSize: CGSize) -> CGRect {
        let x = visionRect.origin.x * containerSize.width
        let y = (1 - visionRect.origin.y - visionRect.height) * containerSize.height
        let w = visionRect.width * containerSize.width
        let h = visionRect.height * containerSize.height
        return CGRect(x: x, y: y, width: w, height: h)
    }

    // MARK: - Colores semánticos por nivel de confianza
    // Verde   ≥ 0.85 → texto limpio, probablemente título o cuerpo
    // Amarillo 0.6–0.85 → posible texto difícil / escritura manual
    // Rojo    < 0.6  → ruido, debe revisarse o descartarse en el procesador
    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.85...: return .green
        case 0.6..<0.85: return .yellow
        default:     return .red
        }
    }
}
