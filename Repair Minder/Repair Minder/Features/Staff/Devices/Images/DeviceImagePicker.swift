//
//  DeviceImagePicker.swift
//  Repair Minder
//
//  Camera capture wrapper + picked-image encoder for device photos (iOS only).
//

#if os(iOS)
import SwiftUI
import UIKit

/// UIKit camera wrapper (PhotosPicker cannot capture live camera).
struct CameraPicker: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    final class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPicker
        init(_ parent: CameraPicker) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImage(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

/// Compress a picked UIImage into an upload-ready JPEG.
enum PickedImageEncoder {
    static func encode(_ image: UIImage) -> PlatformImageData? {
        guard let data = ImageCompressor.compress(image) else { return nil }
        return PlatformImageData(jpegData: data, fileName: "photo.jpg")
    }
}
#endif
