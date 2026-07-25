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

    /// Is a live camera actually usable right now?
    ///
    /// UIImagePickerController RAISES AN EXCEPTION and terminates the app if
    /// sourceType is set to .camera when no camera is available - it is not a
    /// silent no-op. That is a hard crash on the Simulator, and on any device
    /// where the camera is restricted by MDM or parental controls. Apple's docs
    /// require this check before assigning sourceType.
    static var cameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        // Never assign .camera unguarded - see cameraAvailable above.
        picker.sourceType = Self.cameraAvailable ? .camera : .photoLibrary
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
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
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
