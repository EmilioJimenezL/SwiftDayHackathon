// MARK: - DebugMetadataView.swift
// Panel colapsable de metadatos técnicos para debugging y demostración en el hackathon.
//
// Decisión de diseño: Lo separamos de la vista principal para que el equipo de
// frontend pueda ocultarlo o reemplazarlo por una vista de producción sin
// afectar la lógica. En producción, esta información se usará internamente
// para la heurística geométrica, no se mostrará al usuario final.

import SwiftUI

struct DebugMetadataView: View {
    let blocks: [RecognizedBlock]
    let processingTimeMs: Double
    let averageConfidence: Float

    @State private var isExpanded: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // MARK: Header colapsable
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Image(systemName: "ant.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Debug / Metadata")
                        .font(.system(.subheadline, design: .monospaced, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    summaryBadges
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()
                // Stats globales
                statsRow
                Divider()
                // Lista de bloques
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(blocks) { block in
                            BlockMetadataRow(block: block)
                        }
                    }
                    .padding(10)
                }
                .frame(maxHeight: 280)
            }
        }
        .background(Color(.systemBackground).opacity(0.95))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.4), lineWidth: 1)
        )
    }

    // MARK: - Sub-vistas

    private var summaryBadges: some View {
        HStack(spacing: 6) {
            badge("\(blocks.count) bloques", color: .blue)
            badge(String(format: "%.0f ms", processingTimeMs), color: .purple)
        }
    }

    private var statsRow: some View {
        HStack(spacing: 16) {
            statItem(label: "Bloques totales", value: "\(blocks.count)")
            statItem(label: "Confianza media", value: String(format: "%.1f%%", averageConfidence * 100))
            statItem(label: "Tiempo OCR", value: String(format: "%.0f ms", processingTimeMs))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground))
    }

    private func statItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
        }
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

// MARK: - Fila individual de metadatos por bloque

struct BlockMetadataRow: View {
    let block: RecognizedBlock
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Header de la fila
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                // Índice de orden de lectura
                Text("#\(block.readingOrder)")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.indigo)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                // Texto truncado
                Text(block.text)
                    .font(.system(size: 11, design: .default))
                    .lineLimit(isExpanded ? nil : 1)
                    .foregroundStyle(.primary)

                Spacer()

                // Confidence badge con color semántico
                Text(block.confidencePercent)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(confidenceColor(block.confidence))
            }

            // Detalles geométricos expandibles
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    metaLine(label: "UUID", value: block.id.uuidString.prefix(8) + "...")
                    metaLine(label: "BBox", value: block.boundingBoxDescription)
                    metaLine(label: "Confianza", value: String(format: "%.4f", block.confidence))
                }
                .padding(.leading, 24)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.tertiarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private func metaLine(label: String, value: some StringProtocol) -> some View {
        HStack(alignment: .top, spacing: 4) {
            Text(label + ":")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)
            Text(value)
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.primary)
        }
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.85...: return .green
        case 0.6..<0.85: return .yellow
        default:     return .red
        }
    }
}
