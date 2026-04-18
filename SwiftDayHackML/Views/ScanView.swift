// MARK: - ScanView.swift
// Vista principal de la Capa de Percepción.
// Orquesta: selección de imagen → procesamiento OCR → resultados + debug.

import SwiftUI

struct ScanView: View {
    @StateObject private var viewModel = ScanViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {

                    // MARK: 1 — Área de imagen con overlay de bounding boxes
                    imageSection

                    // MARK: 2 — Botones de captura
                    captureButtons

                    // MARK: 3 — Estado de carga o error
                    if viewModel.isProcessing {
                        processingIndicator
                    } else if let error = viewModel.errorMessage {
                        errorBanner(error)
                    }

                    // MARK: 4 — Texto extraído (modo legible)
                    if !viewModel.recognizedBlocks.isEmpty {
                        extractedTextSection
                        debugMetadataSection
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .navigationTitle("LexiScan · OCR")
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

    // MARK: - Sub-vistas

    @ViewBuilder
    private var imageSection: some View {
        ZStack {
            if let image = viewModel.selectedImage {
                // Imagen seleccionada
                GeometryReader { geo in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: geo.size.width)
                        .overlay {
                            // Overlay de bounding boxes solo cuando hay resultados
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

            } else {
                // Placeholder cuando no hay imagen
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
        .animation(.easeInOut(duration: 0.3), value: viewModel.selectedImage != nil)
    }

    private var captureButtons: some View {
        HStack(spacing: 12) {
            // Cámara
            Button {
                viewModel.selectPhoto(from: .camera)
            } label: {
                Label("Cámara", systemImage: "camera.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.indigo)
            .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))

            // Galería
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

    private var processingIndicator: some View {
        HStack(spacing: 10) {
            ProgressView()
                .tint(.indigo)
            Text("Procesando con Vision…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.red.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }

    private var extractedTextSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Texto Extraído", systemImage: "text.alignleft")
                .font(.headline)

            // Lista de bloques ordenados por readingOrder — representa el flujo
            // de lectura que se pasará al InformationProcessor
            ForEach(viewModel.recognizedBlocks.sorted { $0.readingOrder < $1.readingOrder }) { block in
                HStack(alignment: .top, spacing: 8) {
                    // Indicador visual de confianza
                    Circle()
                        .fill(block.confidence >= 0.85 ? Color.green : block.confidence >= 0.6 ? Color.yellow : Color.red)
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
}

// MARK: - Preview
#Preview {
    ScanView()
}
