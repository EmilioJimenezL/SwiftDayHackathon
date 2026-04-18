// MARK: - ScanView.swift
// Vista principal — renderiza ambas fases del pipeline.
//
// Cambio clave respecto a la versión anterior:
//   Usa @ObservedObject en lugar de @StateObject para que el ViewModel
//   pueda ser inyectado desde LexiScanApp (con informationProcessor ya configurado).
//   @StateObject solo se justifica cuando la View es dueña del ciclo de vida
//   del ViewModel; aquí ese rol lo tiene LexiScanApp.

import SwiftUI

struct ScanView: View {

    @ObservedObject var viewModel: ScanViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    imageSection
                    captureButtons
                    statusSection
                    resultsSection

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("LexiScan")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if viewModel.selectedImage != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Limpiar", role: .destructive) {
                            withAnimation { viewModel.clearResults() }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $viewModel.showImagePicker) {
            ImagePickerView(
                selectedImage: Binding(
                    get: { viewModel.selectedImage },
                    set: { image in
                        if let image { viewModel.processImage(image) }
                    }
                ),
                isPresented: $viewModel.showImagePicker,
                sourceType: viewModel.imagePickerSource
            )
        }
    }

    // MARK: - Sección: imagen + overlay

    @ViewBuilder
    private var imageSection: some View {
        if let image = viewModel.selectedImage {
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: geo.size.width)
                    .overlay {
                        if !viewModel.recognizedBlocks.isEmpty {
                            BoundingBoxOverlay(
                                blocks: viewModel.recognizedBlocks,
                                imageSize: image.size
                            )
                        }
                    }
            }
            .frame(height: 260)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .transition(.opacity.combined(with: .scale(scale: 0.97)))
        } else {
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(.secondarySystemBackground))
                .frame(height: 200)
                .overlay {
                    VStack(spacing: 10) {
                        Image(systemName: "viewfinder.triangular")
                            .font(.system(size: 44))
                            .foregroundStyle(.tertiary)
                        Text("Toma una foto o selecciona\nuna imagen de pizarrón")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
        }
    }

    // MARK: - Sección: botones de captura

    private var captureButtons: some View {
        HStack(spacing: 12) {
            Button {
                viewModel.selectPhoto(from: .camera)
            } label: {
                Label("Cámara", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            Button {
                viewModel.selectPhoto(from: .photoLibrary)
            } label: {
                Label("Galería", systemImage: "photo.on.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(.indigo)
        }
        .controlSize(.large)
    }

    // MARK: - Sección: spinners y errores

    @ViewBuilder
    private var statusSection: some View {
        if viewModel.isProcessing {
            pipelineIndicator(
                message: "Leyendo pizarrón con Vision…",
                color: .indigo
            )
        }

        if viewModel.isStructuring {
            pipelineIndicator(
                message: "Organizando con Apple Intelligence…",
                color: .purple
            )
        }

        if let error = viewModel.errorMessage,
           !viewModel.isProcessing,
           !viewModel.isStructuring {
            errorBanner(error)
        }
    }

    private func pipelineIndicator(message: String, color: Color) -> some View {
        HStack(spacing: 10) {
            ProgressView().tint(color)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.red.opacity(0.3), lineWidth: 1))
    }

    // MARK: - Sección: resultados

    @ViewBuilder
    private var resultsSection: some View {
        // Fase 2: contenido semántico estructurado (prioritario si está disponible)
        if let content = viewModel.structuredContent {
            StructuredContentView(content: content)
        }

        // Fase 1: texto crudo — siempre visible cuando hay bloques,
        // incluso mientras Fase 2 está procesando (evita pantalla en blanco)
        if !viewModel.recognizedBlocks.isEmpty {
            rawTextSection
            debugMetadataSection
        }
    }

    // MARK: - Texto crudo (Fase 1)

    private var rawTextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                viewModel.structuredContent != nil ? "OCR Raw" : "Texto Extraído",
                systemImage: "text.alignleft"
            )
            .font(.headline)

            ForEach(viewModel.recognizedBlocks.sorted { $0.readingOrder < $1.readingOrder }) { block in
                HStack(alignment: .top, spacing: 8) {
                    Circle()
                        .fill(confidenceColor(block.confidence))
                        .frame(width: 8, height: 8)
                        .padding(.top, 5)
                    Text(block.text)
                        .font(.body)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
                Divider()
            }
        }
        .padding(14)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var debugMetadataSection: some View {
        DebugMetadataView(
            blocks: viewModel.recognizedBlocks,
            processingTimeMs: viewModel.processingTimeMs,
            averageConfidence: viewModel.averageConfidence
        )
    }

    private func confidenceColor(_ confidence: Float) -> Color {
        switch confidence {
        case 0.85...: return .green
        case 0.6..<0.85: return .yellow
        default: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    // En el Preview construimos el ViewModel sin Foundation Models
    // para no depender de Apple Intelligence en Xcode.
    ScanView(viewModel: ScanViewModel())
}
