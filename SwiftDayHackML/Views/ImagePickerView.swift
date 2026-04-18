// MARK: - ImagePickerView.swift
// Puente UIKit → SwiftUI para acceder a cámara y galería.
//
// Decisión de diseño: Usamos UIImagePickerController en lugar de PhotosPicker
// porque necesitamos soporte tanto de cámara como de galería en un solo componente,
// y UIImagePickerController sigue siendo la opción más estable para este caso.
// PhotosPicker (iOS 16+) es mejor para selección múltiple, que podría ser útil
// en una fase futura donde el usuario suba varias páginas de apuntes.

import SwiftUI
import UIKit

struct ImagePickerView: UIViewControllerRepresentable {

    @Binding var selectedImage: UIImage?
    @Binding var isPresented: Bool
    var sourceType: UIImagePickerController.SourceType = .photoLibrary

    // MARK: - Coordinator (patrón Delegate de UIKit)
    // El Coordinator es el objeto que conforma UIImagePickerControllerDelegate.
    // Vive aquí y no en el ViewModel para mantener la lógica de UIKit dentro del
    // límite de este componente puente — el ViewModel nunca importa UIKit directamente.
    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePickerView

        init(_ parent: ImagePickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            // Preferimos la imagen editada (recortada/girada por el usuario) si existe.
            if let edited = info[.editedImage] as? UIImage {
                parent.selectedImage = edited
            } else if let original = info[.originalImage] as? UIImage {
                parent.selectedImage = original
            }
            parent.isPresented = false
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.isPresented = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = true   // permite al usuario enderezar la foto del pizarrón
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {
        // Sin actualizaciones dinámicas necesarias en esta fase.
    }
}
