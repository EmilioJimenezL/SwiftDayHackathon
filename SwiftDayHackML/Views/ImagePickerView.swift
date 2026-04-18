// MARK: - ImagePickerView.swift
// Puente UIKit → SwiftUI para acceder a cámara y galería.
//
// Usamos UIImagePickerController sobre PhotosPicker porque necesitamos
// soporte de cámara y galería en un solo componente con edición habilitada.
// allowsEditing = true permite al usuario enderezar la foto del pizarrón,
// lo que mejora la calidad del OCR notablemente.

import SwiftUI
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {

    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    // MARK: - Coordinator

    final class Coordinator: NSObject,
        UIImagePickerControllerDelegate,
        UINavigationControllerDelegate
    {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            parent.selectedImage = (info[.editedImage] ?? info[.originalImage]) as? UIImage
            parent.isPresented   = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker          = UIImagePickerController()
        picker.sourceType   = sourceType
        picker.delegate     = context.coordinator
        picker.allowsEditing = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
}
