//
//  DeviceImageGalleryView.swift
//  Repair Minder
//
//  Before/After device photo gallery: view, add (camera/library), delete.
//  iOS only in v1.
//

#if os(iOS)
import SwiftUI
import PhotosUI
import UIKit

struct DeviceImageGalleryView: View {
    let orderId: String
    let deviceId: String
    let deviceStatus: String

    @State private var images: [DeviceImageListItem] = []
    @State private var isLoading = false
    @State private var uploadProgress: String?
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var librarySelection: [PhotosPickerItem] = []

    private let service = DeviceImageService()

    private var preRepair: [DeviceImageListItem] { images.filter { $0.isPreRepair } }
    private var postRepair: [DeviceImageListItem] { images.filter { $0.isPostRepair } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Menu {
                    Button { showCamera = true } label: { Label("Take Photo", systemImage: "camera") }
                    PhotosPicker(selection: $librarySelection, maxSelectionCount: 5, matching: .images) {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Add Photo", systemImage: "plus.circle.fill")
                }
                Spacer()
                if let uploadProgress { Text(uploadProgress).font(.caption).foregroundStyle(.secondary) }
                if isLoading { ProgressView() }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            groupView(title: "Before Repair", items: preRepair, badge: .blue)
            groupView(title: "After Repair", items: postRepair, badge: .green)

            if images.isEmpty && !isLoading {
                Text("No photos yet").font(.caption).foregroundStyle(.secondary)
            }
        }
        .task { await load() }
        .sheet(isPresented: $showCamera) {
            CameraPicker { image in
                Task { await handlePicked(image) }
            }
            .ignoresSafeArea()
        }
        .onChange(of: librarySelection) { _, newItems in
            guard !newItems.isEmpty else { return }
            Task { await handleLibrary(newItems) }
        }
    }

    @ViewBuilder
    private func groupView(title: String, items: [DeviceImageListItem], badge: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.subheadline.bold())
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 8)], spacing: 8) {
                    ForEach(items) { item in
                        AuthenticatedThumbnail(orderId: orderId, deviceId: deviceId, imageId: item.id)
                            .frame(width: 90, height: 90)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(alignment: .topLeading) {
                                Circle().fill(badge).frame(width: 8, height: 8).padding(4)
                            }
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task { await delete(item) }
                                } label: { Label("Delete", systemImage: "trash") }
                            }
                    }
                }
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do { images = try await service.fetchImages(orderId: orderId, deviceId: deviceId) }
        catch { errorMessage = "Couldn't load photos" }
    }

    private func handlePicked(_ image: UIImage) async {
        guard let payload = PickedImageEncoder.encode(image) else {
            errorMessage = "Couldn't process photo"; return
        }
        await upload([payload])
    }

    private func handleLibrary(_ items: [PhotosPickerItem]) async {
        var payloads: [PlatformImageData] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data),
               let payload = PickedImageEncoder.encode(image) {
                payloads.append(payload)
            }
        }
        librarySelection = []
        await upload(payloads)
    }

    private func upload(_ payloads: [PlatformImageData]) async {
        guard !payloads.isEmpty else { return }
        let type = DeviceImageService.imageType(forDeviceStatus: deviceStatus)
        errorMessage = nil
        for (index, payload) in payloads.enumerated() {
            uploadProgress = "Uploading \(index + 1) of \(payloads.count)…"
            do {
                _ = try await service.upload(image: payload, imageType: type, orderId: orderId, deviceId: deviceId)
            } catch {
                errorMessage = "Upload failed for photo \(index + 1)"
            }
        }
        uploadProgress = nil
        await load()
    }

    private func delete(_ item: DeviceImageListItem) async {
        do {
            try await service.delete(orderId: orderId, deviceId: deviceId, imageId: item.id)
            images.removeAll { $0.id == item.id }
        } catch {
            errorMessage = "Couldn't delete photo"
        }
    }
}

/// Loads an authenticated device image thumbnail via APIClient.requestRawData.
struct AuthenticatedThumbnail: View {
    let orderId: String
    let deviceId: String
    let imageId: String

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                Rectangle().fill(.gray.opacity(0.15)).overlay { ProgressView() }
            }
        }
        .task { await loadWithRetry() }
    }

    // R2 is eventually consistent right after upload; retry a few times.
    private func loadWithRetry() async {
        for attempt in 0..<3 {
            do {
                let data = try await APIClient.shared.requestRawData(
                    .deviceImageFile(orderId: orderId, deviceId: deviceId, imageId: imageId)
                )
                if let image = UIImage(data: data) { uiImage = image; return }
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64((attempt + 1) * 400) * 1_000_000)
                }
            }
        }
    }
}
#endif
