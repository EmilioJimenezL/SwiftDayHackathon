//
//  CameraPickerView.swift
//
//  Created by Rafael on 18/04/26.
//

import SwiftUI
import UIKit

struct CameraPickerView: UIViewControllerRepresentable {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType           = .camera
        picker.cameraCaptureMode    = .photo
        picker.showsCameraControls  = true
        picker.delegate             = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    // MARK: - Coordinator
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) { self.parent = parent }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.appState.didCaptureImage(image)
            }
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.appState.cancelCapture()
        }
    }
}
