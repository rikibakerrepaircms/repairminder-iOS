# Stage 04: Camera Integration

## Objective
Enable staff to capture photos using the device camera and upload them to the device record.

## Dependencies
`[Requires: Stage 03 complete]` - Needs gallery to display uploaded photos

## Complexity
**Medium** - Camera permissions, image picker, upload with progress

---

## Files to Create

### 1. `Features/Staff/Devices/Camera/CameraPickerView.swift`
SwiftUI wrapper for UIImagePickerController.

### 2. `Features/Staff/Devices/Camera/ImageUploadSheet.swift`
Sheet for selecting image type and adding caption before upload.

### 3. `Features/Staff/Devices/Camera/UploadProgressView.swift`
Progress indicator during upload.

---

## Files to Modify

### 1. `Info.plist` (via Xcode project)
Add camera and photo library usage descriptions.

### 2. `Features/Staff/Devices/Gallery/DeviceImageGalleryView.swift`
Add "Take Photo" button.

### 3. `Features/Staff/Devices/DeviceDetailView.swift`
Add quick "Take Photo" action.

---

## Implementation Details

### Info.plist Entries

Add via Xcode Target → Info:
```xml
<key>NSCameraUsageDescription</key>
<string>Repair Minder needs camera access to take photos of devices during diagnosis and repair.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Repair Minder needs photo library access to select existing photos for device records.</string>
```

### CameraPickerView.swift

```swift
import SwiftUI
import PhotosUI

// MARK: - Camera Picker View

/// SwiftUI wrapper for camera and photo library access
struct CameraPickerView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss

    let sourceType: UIImagePickerController.SourceType
    let onImageCaptured: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        picker.allowsEditing = false

        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
            picker.cameraDevice = .rear
        }

        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            if let image = info[.originalImage] as? UIImage {
                parent.onImageCaptured(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

// MARK: - Photo Picker View (iOS 16+)

/// Modern photo picker using PhotosUI
struct PhotoPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedItem: PhotosPickerItem?

    let onImageSelected: (UIImage) -> Void

    var body: some View {
        PhotosPicker(
            selection: $selectedItem,
            matching: .images,
            photoLibrary: .shared()
        ) {
            Text("Select from Library")
        }
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    onImageSelected(image)
                    dismiss()
                }
            }
        }
    }
}
```

### ImageUploadSheet.swift

```swift
import SwiftUI

// MARK: - Image Upload Sheet

/// Sheet for configuring image upload (type, caption)
struct ImageUploadSheet: View {
    let image: UIImage
    let orderId: String
    let deviceId: String
    let onComplete: (DeviceImageInfo) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: DeviceImageType = .preRepair
    @State private var caption = ""
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var error: String?

    private let imageService = ImageService.shared

    var body: some View {
        NavigationStack {
            Form {
                // Preview
                Section {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 200)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                // Image type
                Section("Photo Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(DeviceImageType.allCases, id: \.self) { type in
                            Label(type.displayName, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Caption
                Section("Caption (Optional)") {
                    TextField("Add a description...", text: $caption, axis: .vertical)
                        .lineLimit(3...6)
                }

                // Error
                if let error = error {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }

                // Upload progress
                if isUploading {
                    Section {
                        VStack(spacing: 8) {
                            ProgressView(value: uploadProgress)
                            Text("Uploading... \(Int(uploadProgress * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Upload Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isUploading)
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Upload") {
                        Task { await uploadImage() }
                    }
                    .disabled(isUploading)
                }
            }
            .interactiveDismissDisabled(isUploading)
        }
    }

    private func uploadImage() async {
        isUploading = true
        error = nil
        uploadProgress = 0

        do {
            let imageInfo = try await imageService.uploadImage(
                image,
                orderId: orderId,
                deviceId: deviceId,
                imageType: selectedType,
                caption: caption.isEmpty ? nil : caption,
                progressHandler: { progress in
                    Task { @MainActor in
                        uploadProgress = progress
                    }
                }
            )

            onComplete(imageInfo)
            dismiss()
        } catch {
            self.error = error.localizedDescription
            isUploading = false
        }
    }
}
```

### UploadProgressView.swift

```swift
import SwiftUI

// MARK: - Upload Progress View

/// Inline progress indicator for image uploads
struct UploadProgressView: View {
    let progress: Double
    let fileName: String?

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 3)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                if progress >= 1.0 {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(Int(progress * 100))")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(progress >= 1.0 ? "Upload complete" : "Uploading...")
                    .font(.subheadline)

                if let fileName = fileName {
                    Text(fileName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

### Update DeviceImageGalleryView.swift

Add to toolbar and state:

```swift
// Add to state variables
@State private var showingImageSourcePicker = false
@State private var showingCamera = false
@State private var showingPhotoLibrary = false
@State private var capturedImage: UIImage?
@State private var showingUploadSheet = false

// Add to toolbar
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Menu {
            Button {
                showingCamera = true
            } label: {
                Label("Take Photo", systemImage: "camera")
            }

            Button {
                showingPhotoLibrary = true
            } label: {
                Label("Choose from Library", systemImage: "photo.on.rectangle")
            }
        } label: {
            Image(systemName: "plus")
        }
    }
}
.fullScreenCover(isPresented: $showingCamera) {
    CameraPickerView(sourceType: .camera) { image in
        capturedImage = image
        showingUploadSheet = true
    }
}
.sheet(isPresented: $showingPhotoLibrary) {
    CameraPickerView(sourceType: .photoLibrary) { image in
        capturedImage = image
        showingUploadSheet = true
    }
}
.sheet(isPresented: $showingUploadSheet) {
    if let image = capturedImage {
        ImageUploadSheet(
            image: image,
            orderId: orderId,
            deviceId: deviceId
        ) { imageInfo in
            // Add to images array and refresh
            images.insert(imageInfo, at: 0)
            capturedImage = nil
        }
    }
}
```

### Update DeviceDetailView.swift

Add quick photo action to status section:

```swift
// In statusSection, add before the available actions:
// Quick photo button
Button {
    showingQuickPhoto = true
} label: {
    HStack {
        Image(systemName: "camera.fill")
            .foregroundStyle(.blue)
        Text("Take Photo")
        Spacer()
        Image(systemName: "chevron.right")
            .font(.caption)
            .foregroundStyle(.tertiary)
    }
}

// Add state variable
@State private var showingQuickPhoto = false
@State private var quickPhotoImage: UIImage?
@State private var showingQuickPhotoUpload = false

// Add sheet modifiers
.fullScreenCover(isPresented: $showingQuickPhoto) {
    CameraPickerView(sourceType: .camera) { image in
        quickPhotoImage = image
        showingQuickPhotoUpload = true
    }
}
.sheet(isPresented: $showingQuickPhotoUpload) {
    if let image = quickPhotoImage {
        ImageUploadSheet(
            image: image,
            orderId: viewModel.orderId,
            deviceId: viewModel.deviceId
        ) { _ in
            // Refresh device to update photo count
            Task { await viewModel.refresh() }
            quickPhotoImage = nil
        }
    }
}
```

---

## Database Changes
None

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Camera permission prompt | First camera access | System prompt appears |
| Camera captures photo | Take photo | Image appears in upload sheet |
| Photo library access | Select photo | Image appears in upload sheet |
| Image type selection | Select "Damage" | Uploads with damage type |
| Caption saved | Enter "Screen crack" | Caption visible in gallery |
| Upload progress shown | Large image | Progress updates 0→100% |
| Upload error handled | Network failure | Error message shown |
| Gallery refreshes | Complete upload | New image in grid |

---

## Acceptance Checklist

- [ ] Info.plist contains camera usage description
- [ ] Info.plist contains photo library usage description
- [ ] Camera picker opens and captures photos
- [ ] Photo library picker opens and selects photos
- [ ] Image upload sheet allows type and caption selection
- [ ] Upload progress is displayed
- [ ] Successful upload appears in gallery
- [ ] Error handling shows user-friendly messages
- [ ] Quick photo from device detail works
- [ ] Build passes with no errors

---

## Deployment
```bash
# Test on real device (simulator doesn't have camera)
# Or test photo library on simulator
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- Camera only works on real device; photo library works in simulator
- Images are compressed to max 2048px and 80% JPEG quality before upload
- The `CameraPickerView` handles both camera and photo library via `sourceType`
- Stage 05 can proceed independently (inline editing)
