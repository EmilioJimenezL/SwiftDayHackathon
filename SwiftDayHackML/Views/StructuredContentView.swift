// MARK: - StructuredContentView.swift
// Renderiza el StructuredContent producido por FoundationModelsProcessor.
//
// Principios de diseño de accesibilidad aplicados:
//   - Resumen ejecutivo primero: reduce carga cognitiva inicial para dislexia.
//   - Chips táctiles de conceptos: navegación rápida sin leer todo el texto.
//   - Viñetas cortas: facilita la lectura fragmentada preferida por muchos
//     usuarios con dislexia.
//   - Bloque especial para fórmulas: fuente monoespaciada + padding extra
//     da respiro visual para usuarios con discalculia.
//   - Indicador de confianza en secciones: alerta visualmente sobre contenido
//     OCR poco confiable sin interrumpir el flujo de lectura.

import SwiftUI

struct StructuredContentView: View {
    let content: StructuredContent

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            headerSection
            summarySection
            keyConceptsSection

            ForEach(content.sections, id: \.title) { section in
                SectionCardView(section: section)
            }

            if let formulas = content.mathFound, !formulas.isEmpty {
                mathSection(formulas)
            }

            metadataFooter
        }
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.25), lineWidth: 1)
        )
    }

    // MARK: - Sub-vistas

    private var headerSection: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                // Badge de Fase 2
                Label("Apple Intelligence", systemImage: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.purple)

                Text(content.mainTitle)
                    .font(.system(.title2, design: .rounded, weight: .bold))
            }
            Spacer()
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Resumen", systemImage: "text.quote")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            Text(content.summary)
                .font(.body)
                .lineSpacing(5)
                .padding(12)
                .background(Color.indigo.opacity(0.07))
                .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var keyConceptsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Conceptos clave", systemImage: "tag")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            // ScrollView horizontal para que los chips no colapsen el layout
            // en pantallas estrechas — importante para accesibilidad móvil.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(content.keyConcepts, id: \.self) { concept in
                        Text(concept)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.indigo)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Color.indigo.opacity(0.10))
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 1) // evita que las cápsulas se recorten
            }
        }
    }

    private func mathSection(_ formulas: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Fórmulas", systemImage: "function")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(formulas, id: \.self) { formula in
                Text(formula)
                    // Monoespaciado: alinea dígitos y operadores, reduce
                    // ambigüedad visual para discalculia.
                    .font(.system(.body, design: .monospaced))
                    .lineSpacing(8)   // espacio extra entre líneas de fórmulas
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
            }
        }
    }

    private var metadataFooter: some View {
        let meta = content.processingMetadata
        return HStack(spacing: 12) {
            metaChip(
                label: "\(meta.totalBlocksReceived) bloques",
                icon: "square.grid.2x2",
                color: .secondary
            )
            if meta.blocksDiscarded > 0 {
                metaChip(
                    label: "\(meta.blocksDiscarded) descartados",
                    icon: "xmark.circle",
                    color: .red
                )
            }
            if meta.blocksFlagged > 0 {
                metaChip(
                    label: "\(meta.blocksFlagged) dudosos",
                    icon: "exclamationmark.triangle",
                    color: .yellow
                )
            }
            Spacer()
            metaChip(
                label: String(format: "%.0f ms", meta.processingTimeMs),
                icon: "clock",
                color: .secondary
            )
        }
    }

    private func metaChip(label: String, icon: String, color: Color) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.system(size: 10, weight: .medium, design: .monospaced))
        .foregroundStyle(color)
    }
}

// MARK: - Tarjeta de sección individual

struct SectionCardView: View {
    let section: Section

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(section.title)
                    .font(.headline)
                Spacer()
                // Advertencia discreta si la confianza OCR de la sección es baja
                if section.confidenceLevel < 0.70 {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.yellow)
                        .font(.caption)
                }
            }

            // Separador sutil entre título y viñetas
            Rectangle()
                .fill(Color.indigo.opacity(0.2))
                .frame(height: 1)

            ForEach(section.bullets, id: \.self) { bullet in
                HStack(alignment: .top, spacing: 10) {
                    // Punto de viñeta: tamaño fijo para alineación consistente
                    Circle()
                        .fill(Color.indigo.opacity(0.6))
                        .frame(width: 6, height: 6)
                        .padding(.top, 7)
                    Text(bullet)
                        .font(.body)
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        StructuredContentView(content: StructuredContent(
            mainTitle: "Fotosíntesis",
            summary: "La fotosíntesis es el proceso por el cual las plantas convierten luz solar en glucosa. Es fundamental para la vida en la Tierra y ocurre en los cloroplastos.",
            sections: [
                Section(
                    title: "Proceso principal",
                    bullets: [
                        "Las plantas capturan la luz del sol con la clorofila.",
                        "El CO₂ del aire y el agua del suelo se combinan.",
                        "Se produce glucosa como fuente de energía.",
                        "El oxígeno se libera como subproducto."
                    ],
                    confidenceLevel: 0.91
                ),
                Section(
                    title: "Factores que afectan la tasa",
                    bullets: [
                        "Intensidad de la luz: más luz → más fotosíntesis hasta un límite.",
                        "Concentración de CO₂: factor limitante en ambientes cerrados.",
                        "Temperatura: rango óptimo entre 25–35 °C para la mayoría de plantas."
                    ],
                    confidenceLevel: 0.62
                )
            ],
            keyConcepts: ["fotosíntesis", "clorofila", "cloroplasto", "glucosa", "CO₂"],
            mathFound: ["6CO₂ + 6H₂O + luz → C₆H₁₂O₆ + 6O₂"],
            processingMetadata: ProcessingMetadata(
                totalBlocksReceived: 12,
                blocksDiscarded: 1,
                blocksFlagged: 2,
                discardThreshold: 0.50,
                processingTimeMs: 3240
            )
        ))
        .padding()
    }
}
