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
    let orderNumber: Int?
    let serialNumber: String?
    let imei: String?

    @State private var images: [DeviceImageListItem] = []
    @State private var isLoading = false
    @State private var uploadProgress: String?
    @State private var errorMessage: String?
    @State private var showCamera = false
    @State private var librarySelection: [PhotosPickerItem] = []
    @State private var selectedItem: DeviceImageListItem?

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
        .fullScreenCover(item: $selectedItem) { item in
            DeviceImagePhotoViewer(
                orderId: orderId,
                deviceId: deviceId,
                imageId: item.id,
                fileName: item.filename,
                imageType: item.imageType,
                onSaved: { Task { await load() } }
            )
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
                            .contentShape(Rectangle())
                            .onTapGesture { selectedItem = item }
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

    /// Build a descriptive base filename: {order}_{serialOrImei}_{before|after}
    private func baseFileName(imageType: String) -> String {
        let tag = imageType == "pre_repair" ? "before" : "after"
        func clean(_ s: String) -> String {
            String(s.unicodeScalars.filter { CharacterSet.alphanumerics.contains($0) || $0 == "-" })
        }
        var parts: [String] = []
        if let orderNumber { parts.append(String(orderNumber)) }
        if let serialNumber, !serialNumber.isEmpty { parts.append(clean(serialNumber)) }
        else if let imei, !imei.isEmpty { parts.append(clean(imei)) }
        parts.append(tag)
        let base = parts.joined(separator: "_")
        return base.isEmpty ? "device-photo" : base
    }

    private func upload(_ payloads: [PlatformImageData]) async {
        guard !payloads.isEmpty else { return }
        let type = DeviceImageService.imageType(forDeviceStatus: deviceStatus)
        let base = baseFileName(imageType: type)
        errorMessage = nil
        var failures = 0
        for (index, payload) in payloads.enumerated() {
            uploadProgress = "Uploading \(index + 1) of \(payloads.count)…"
            let suffix = payloads.count > 1 ? "_\(index + 1)" : ""
            let named = PlatformImageData(jpegData: payload.jpegData, fileName: "\(base)\(suffix).jpg")
            do {
                _ = try await service.upload(image: named, imageType: type, orderId: orderId, deviceId: deviceId)
            } catch {
                failures += 1
            }
        }
        uploadProgress = nil
        await load()
        // Surface upload failures AFTER reload so a successful load() doesn't hide them,
        // and a load() error doesn't get masked by a per-photo message.
        if failures > 0 && errorMessage == nil {
            errorMessage = failures == 1 ? "1 photo failed to upload" : "\(failures) photos failed to upload"
        }
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
    @State private var failed = false

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else if failed {
                Rectangle().fill(.gray.opacity(0.15))
                    .overlay { Image(systemName: "photo.slash").foregroundStyle(.secondary) }
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
                    .deviceImageFile(orderId: orderId, deviceId: deviceId, imageId: imageId, width: 240, height: 240)
                )
                if let image = UIImage(data: data) { uiImage = image; return }
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 400 * 1_000_000)
                }
            }
        }
        failed = true
    }
}
#endif
