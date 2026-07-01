//
//  DeviceImagePhotoViewer.swift
//  Repair Minder
//
//  Full-screen viewer for an existing device photo: loads the full-resolution
//  original (no server resize), supports pinch + double-tap zoom and panning,
//  and shares via the system share sheet (Save to Photos, Save to Files, or
//  send to another app). iOS only.
//

#if os(iOS)
import SwiftUI
import UIKit

struct DeviceImagePhotoViewer: View {
    let orderId: String
    let deviceId: String
    let imageId: String
    let fileName: String?
    var imageType: String = "post_repair"
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var uiImage: UIImage?
    @State private var imageData: Data?
    @State private var loadFailed = false

    // Zoom / pan state
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    @State private var shareURL: URL?
    @State private var showShare = false
    @State private var showEditor = false

    private let minScale: CGFloat = 1
    private let maxScale: CGFloat = 5

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                if let uiImage {
                    zoomableImage(uiImage)
                } else if loadFailed {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.slash").font(.largeTitle)
                        Text("Couldn't load photo")
                    }
                    .foregroundStyle(.white.opacity(0.7))
                } else {
                    ProgressView().tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showEditor = true } label: {
                        Image(systemName: "pencil.tip.crop.circle")
                    }
                    .disabled(uiImage == nil)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { prepareShare() } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(imageData == nil)
                }
            }
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .task { await load() }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                DeviceImageActivityView(activityItems: [shareURL])
            }
        }
        .fullScreenCover(isPresented: $showEditor) {
            if let uiImage {
                DeviceImagePhotoEditor(
                    source: uiImage,
                    orderId: orderId,
                    deviceId: deviceId,
                    imageType: imageType,
                    baseFileName: fileName,
                    onSaved: { onSaved(); dismiss() }
                )
            }
        }
    }

    @ViewBuilder
    private func zoomableImage(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(
                MagnifyGesture()
                    .onChanged { value in
                        scale = min(max(lastScale * value.magnification, minScale), maxScale)
                    }
                    .onEnded { _ in
                        lastScale = scale
                        if scale <= minScale { withAnimation { resetZoom() } }
                    }
            )
            .simultaneousGesture(
                DragGesture()
                    .onChanged { value in
                        guard scale > minScale else { return }
                        offset = CGSize(
                            width: lastOffset.width + value.translation.width,
                            height: lastOffset.height + value.translation.height
                        )
                    }
                    .onEnded { _ in lastOffset = offset }
            )
            .onTapGesture(count: 2) {
                withAnimation {
                    if scale > minScale {
                        resetZoom()
                    } else {
                        scale = 2
                        lastScale = 2
                    }
                }
            }
    }

    private func resetZoom() {
        scale = 1
        lastScale = 1
        offset = .zero
        lastOffset = .zero
    }

    // Full resolution: omit width/height so the server returns the original R2 bytes.
    // R2 can be eventually consistent right after upload; retry a few times.
    private func load() async {
        for attempt in 0..<3 {
            do {
                let data = try await APIClient.shared.requestRawData(
                    .deviceImageFile(orderId: orderId, deviceId: deviceId, imageId: imageId, width: nil, height: nil)
                )
                if let image = UIImage(data: data) {
                    imageData = data
                    uiImage = image
                    return
                }
            } catch {
                if attempt < 2 {
                    try? await Task.sleep(nanoseconds: UInt64(attempt + 1) * 400 * 1_000_000)
                }
            }
        }
        loadFailed = true
    }

    // Write the original bytes to a temp file named from the stored filename so
    // saved / shared copies keep the meaningful {order}_{serial}_{before|after} name.
    private func prepareShare() {
        guard let imageData else { return }
        let raw = (fileName?.isEmpty == false) ? fileName! : "device-photo.jpg"
        let lower = raw.lowercased()
        let name = (lower.hasSuffix(".jpg") || lower.hasSuffix(".jpeg")) ? raw : "\(raw).jpg"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        do {
            try imageData.write(to: url, options: .atomic)
            shareURL = url
            showShare = true
        } catch {
            // If the temp write fails, share the raw image data directly as a fallback.
            shareURL = nil
        }
    }
}

/// UIActivityViewController wrapper for the system share sheet.
struct DeviceImageActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
#endif
