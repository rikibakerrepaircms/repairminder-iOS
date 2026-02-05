# Stage 03: Photo Gallery

## Objective
Create a photo gallery view that displays device images in a grid with category filtering and full-screen viewing.

## Dependencies
`[Requires: Stage 02 complete]` - Needs ImageService for loading images

## Complexity
**Medium** - Multiple view components with async image loading

---

## Files to Create

### 1. `Features/Staff/Devices/Gallery/DeviceImageGalleryView.swift`
Main gallery container with filter tabs and grid.

### 2. `Features/Staff/Devices/Gallery/DeviceImageGridView.swift`
Grid layout for image thumbnails.

### 3. `Features/Staff/Devices/Gallery/FullScreenImageViewer.swift`
Full-screen image view with swipe navigation.

### 4. `Features/Staff/Devices/Gallery/AsyncDeviceImage.swift`
Reusable async image loading component.

---

## Files to Modify

### 1. `Features/Staff/Devices/DeviceDetailView.swift`
Replace simple photo count with gallery navigation.

---

## Implementation Details

### DeviceImageGalleryView.swift

```swift
import SwiftUI

// MARK: - Device Image Gallery View

/// Gallery view showing all images for a device
struct DeviceImageGalleryView: View {
    let orderId: String
    let deviceId: String

    @State private var images: [DeviceImageInfo] = []
    @State private var counts = ImageTypeCounts(preRepair: nil, postRepair: nil, damage: nil, diagnostic: nil, part: nil)
    @State private var selectedType: DeviceImageType?
    @State private var isLoading = true
    @State private var error: String?
    @State private var selectedImage: DeviceImageInfo?

    private let imageService = ImageService.shared

    var body: some View {
        VStack(spacing: 0) {
            // Type filter tabs
            imageTypeFilter

            // Content
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = error {
                ContentUnavailableView {
                    Label("Error", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                } actions: {
                    Button("Retry") {
                        Task { await loadImages() }
                    }
                }
            } else if filteredImages.isEmpty {
                ContentUnavailableView {
                    Label("No Photos", systemImage: "photo.on.rectangle.angled")
                } description: {
                    Text(selectedType == nil ? "No photos have been taken" : "No \(selectedType!.displayName.lowercased()) photos")
                }
            } else {
                DeviceImageGridView(
                    images: filteredImages,
                    orderId: orderId,
                    deviceId: deviceId,
                    onImageTap: { image in
                        selectedImage = image
                    }
                )
            }
        }
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadImages()
        }
        .refreshable {
            await loadImages()
        }
        .fullScreenCover(item: $selectedImage) { image in
            FullScreenImageViewer(
                images: filteredImages,
                initialImage: image,
                orderId: orderId,
                deviceId: deviceId
            )
        }
    }

    // MARK: - Filter Tabs

    private var imageTypeFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                FilterChip(
                    title: "All",
                    count: counts.total,
                    isSelected: selectedType == nil
                ) {
                    selectedType = nil
                }

                ForEach(DeviceImageType.allCases, id: \.self) { type in
                    FilterChip(
                        title: type.displayName,
                        count: count(for: type),
                        isSelected: selectedType == type
                    ) {
                        selectedType = type
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    private func count(for type: DeviceImageType) -> Int {
        switch type {
        case .preRepair: return counts.preRepair ?? 0
        case .postRepair: return counts.postRepair ?? 0
        case .damage: return counts.damage ?? 0
        case .diagnostic: return counts.diagnostic ?? 0
        case .part: return counts.part ?? 0
        }
    }

    private var filteredImages: [DeviceImageInfo] {
        guard let type = selectedType else { return images }
        return images.filter { $0.imageType == type.rawValue }
    }

    // MARK: - Data Loading

    private func loadImages() async {
        isLoading = true
        error = nil

        do {
            let response = try await imageService.listImages(
                orderId: orderId,
                deviceId: deviceId
            )
            images = response.images
            counts = response.counts
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Text(title)
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(isSelected ? Color.white.opacity(0.3) : Color(.tertiarySystemFill))
                        .clipShape(Capsule())
                }
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue : Color(.tertiarySystemGroupedBackground))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
```

### DeviceImageGridView.swift

```swift
import SwiftUI

// MARK: - Device Image Grid View

/// Grid display of image thumbnails
struct DeviceImageGridView: View {
    let images: [DeviceImageInfo]
    let orderId: String
    let deviceId: String
    let onImageTap: (DeviceImageInfo) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 4)
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(images) { image in
                    ImageThumbnail(
                        image: image,
                        orderId: orderId,
                        deviceId: deviceId
                    )
                    .onTapGesture {
                        onImageTap(image)
                    }
                }
            }
            .padding(4)
        }
    }
}

// MARK: - Image Thumbnail

private struct ImageThumbnail: View {
    let image: DeviceImageInfo
    let orderId: String
    let deviceId: String

    var body: some View {
        AsyncDeviceImage(
            orderId: orderId,
            deviceId: deviceId,
            imageId: image.id,
            thumbnail: true
        )
        .aspectRatio(1, contentMode: .fill)
        .clipped()
        .overlay(alignment: .bottomLeading) {
            // Image type badge
            if let type = DeviceImageType(rawValue: image.imageType) {
                Text(type.displayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .padding(4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

### FullScreenImageViewer.swift

```swift
import SwiftUI

// MARK: - Full Screen Image Viewer

/// Full-screen image viewer with swipe navigation
struct FullScreenImageViewer: View {
    let images: [DeviceImageInfo]
    let initialImage: DeviceImageInfo
    let orderId: String
    let deviceId: String

    @Environment(\.dismiss) private var dismiss
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero

    init(images: [DeviceImageInfo], initialImage: DeviceImageInfo, orderId: String, deviceId: String) {
        self.images = images
        self.initialImage = initialImage
        self.orderId = orderId
        self.deviceId = deviceId
        self._currentIndex = State(initialValue: images.firstIndex(where: { $0.id == initialImage.id }) ?? 0)
    }

    var body: some View {
        NavigationStack {
            TabView(selection: $currentIndex) {
                ForEach(Array(images.enumerated()), id: \.element.id) { index, image in
                    ZoomableImageView(
                        orderId: orderId,
                        deviceId: deviceId,
                        imageId: image.id
                    )
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .automatic))
            .background(Color.black)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        if let type = DeviceImageType(rawValue: currentImage.imageType) {
                            Text(type.displayName)
                                .font(.headline)
                        }
                        Text("\(currentIndex + 1) of \(images.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        if let caption = currentImage.caption {
                            Section {
                                Text(caption)
                            }
                        }
                        Button {
                            // Share action
                        } label: {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private var currentImage: DeviceImageInfo {
        images[currentIndex]
    }
}

// MARK: - Zoomable Image View

private struct ZoomableImageView: View {
    let orderId: String
    let deviceId: String
    let imageId: String

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0

    var body: some View {
        AsyncDeviceImage(
            orderId: orderId,
            deviceId: deviceId,
            imageId: imageId,
            thumbnail: false
        )
        .aspectRatio(contentMode: .fit)
        .scaleEffect(scale)
        .gesture(
            MagnificationGesture()
                .onChanged { value in
                    scale = lastScale * value
                }
                .onEnded { _ in
                    lastScale = scale
                    if scale < 1.0 {
                        withAnimation {
                            scale = 1.0
                            lastScale = 1.0
                        }
                    }
                }
        )
        .onTapGesture(count: 2) {
            withAnimation {
                if scale > 1.0 {
                    scale = 1.0
                    lastScale = 1.0
                } else {
                    scale = 2.5
                    lastScale = 2.5
                }
            }
        }
    }
}
```

### AsyncDeviceImage.swift

```swift
import SwiftUI

// MARK: - Async Device Image

/// Async loading image component for device images
struct AsyncDeviceImage: View {
    let orderId: String
    let deviceId: String
    let imageId: String
    let thumbnail: Bool

    @State private var image: Image?
    @State private var isLoading = true
    @State private var loadFailed = false

    private let imageService = ImageService.shared

    var body: some View {
        Group {
            if let image = image {
                image
                    .resizable()
            } else if loadFailed {
                Color(.systemGray5)
                    .overlay {
                        Image(systemName: "exclamationmark.triangle")
                            .foregroundStyle(.secondary)
                    }
            } else {
                Color(.systemGray6)
                    .overlay {
                        ProgressView()
                    }
            }
        }
        .task(id: "\(orderId)/\(deviceId)/\(imageId)/\(thumbnail)") {
            await loadImage()
        }
    }

    private func loadImage() async {
        isLoading = true
        loadFailed = false

        do {
            let swiftUIImage = try await imageService.loadSwiftUIImage(
                orderId: orderId,
                deviceId: deviceId,
                imageId: imageId,
                thumbnail: thumbnail
            )
            self.image = swiftUIImage
        } catch {
            loadFailed = true
            print("Failed to load image: \(error)")
        }

        isLoading = false
    }
}
```

### Update DeviceDetailView.swift - Images Section

Replace the existing `imagesSection` with:

```swift
// MARK: - Images Section

private func imagesSection(_ device: DeviceDetail) -> some View {
    Section {
        NavigationLink {
            DeviceImageGalleryView(
                orderId: viewModel.orderId,
                deviceId: viewModel.deviceId
            )
        } label: {
            HStack {
                Label {
                    Text("Photos")
                } icon: {
                    Image(systemName: "photo.on.rectangle.angled")
                        .foregroundStyle(.blue)
                }

                Spacer()

                Text("\(device.images.count)")
                    .foregroundStyle(.secondary)

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }

        // Preview thumbnails (first 3 images)
        if !device.images.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(device.images.prefix(3)) { image in
                        AsyncDeviceImage(
                            orderId: viewModel.orderId,
                            deviceId: viewModel.deviceId,
                            imageId: image.id,
                            thumbnail: true
                        )
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if device.images.count > 3 {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.tertiarySystemFill))
                            .frame(width: 80, height: 80)
                            .overlay {
                                Text("+\(device.images.count - 3)")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                            }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    } header: {
        Text("Photos")
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
| Gallery shows all images | Device with 5 images | Grid shows 5 thumbnails |
| Filter by type | Select "Pre-Repair" | Only pre-repair images shown |
| Full-screen viewer opens | Tap thumbnail | Full-screen view appears |
| Swipe navigation works | Swipe left/right | Shows next/prev image |
| Pinch zoom works | Pinch gesture | Image scales |
| Double-tap toggles zoom | Double-tap | Zooms in/out |

---

## Acceptance Checklist

- [ ] DeviceImageGalleryView displays images in grid
- [ ] Type filter tabs show correct counts
- [ ] Tapping thumbnail opens full-screen viewer
- [ ] Full-screen viewer supports swipe navigation
- [ ] Pinch-to-zoom works
- [ ] Double-tap zoom works
- [ ] DeviceDetailView shows photo count and preview thumbnails
- [ ] NavigationLink to gallery works
- [ ] Empty states display correctly
- [ ] Loading states display correctly
- [ ] Build passes with no errors

---

## Deployment
```bash
xcodebuild -scheme "Repair Minder" -destination "generic/platform=iOS Simulator" build
```

---

## Handoff Notes
- Stage 04 will add a "Take Photo" button to the gallery
- The `AsyncDeviceImage` component is reusable elsewhere
- Image loading uses `ImageService.shared` with caching
- Full-screen viewer uses `.preferredColorScheme(.dark)` for better viewing
