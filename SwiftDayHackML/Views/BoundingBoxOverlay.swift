// MARK: - BoundingBoxOverlay.swift
// Dibuja los bounding boxes de Vision sobre la imagen con código de colores
// por nivel de confianza.
//
// Transformación de coordenadas (crítica):
//   Vision usa origen inferior-izquierdo; SwiftUI usa origen superior-izquierdo.
//   y_swiftui = (1 - y_vision - height_vision) * containerHeight

import SwiftUI

struct BoundingBoxOverlay: View {
    let blocks: [RecognizedBlock]
    let imageSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            ForEach(blocks) { block in
                let rect = transformedRect(visionRect: block.boundingBox, in: geometry.size)

                Rectangle()
                    .stroke(confidenceColor(block.confidence), lineWidth: 1.5)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                    .overlay(alignment: .topLeading) {
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

    // MARK: - Privado

    private func transformedRect(visionRect: CGRect, in containerSize: CGSize) -> CGRect {
        CGRect(
            x: visionRect.origin.x * containerSize.width,
            y: (1 - visionRect.origin.y - visionRect.height) * containerSize.height,
            width:  visionRect.width  * containerSize.width,
            height: visionRect.height * containerSize.height
        )
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.85...:     return .green
        case 0.6..<0.85: return .yellow
        default:          return .red
        }
    }
}
