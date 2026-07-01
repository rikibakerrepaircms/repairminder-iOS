//
//  DeviceImagePhotoEditor.swift
//  Repair Minder
//
//  Basic photo editor for device images: draw (PencilKit pen/pencil/marker +
//  stroke eraser + undo), redact a region (blur or black-out via Core Image),
//  and crop. The edited result can be exported (share sheet) or saved back to
//  the device order as a new photo. iOS only.
//
//  Note: Apple's generative "Clean Up" object removal has no third-party API,
//  so redaction here is blur / black-out. If a public API ships, an "AI Erase"
//  mode can be added alongside the existing modes.
//

#if os(iOS)
import SwiftUI
import PencilKit
import UIKit
import CoreImage

struct DeviceImagePhotoEditor: View {
    let source: UIImage
    let orderId: String
    let deviceId: String
    let imageType: String        // "pre_repair" / "post_repair"
    let baseFileName: String?    // e.g. "10432_356..._before"
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var working: UIImage
    @State private var history: [UIImage] = []          // for undo of destructive ops
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    @State private var mode: EditMode = .draw
    @State private var containerSize: CGSize = .zero
    @State private var selection: CGRect?               // in displayRect-local points

    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var shareURL: URL?
    @State private var showShare = false

    enum EditMode: String, CaseIterable, Identifiable {
        case draw = "Draw"
        case blur = "Blur"
        case blackout = "Black-out"
        case crop = "Crop"
        var id: String { rawValue }
    }

    init(source: UIImage, orderId: String, deviceId: String, imageType: String,
         baseFileName: String?, onSaved: @escaping () -> Void = {}) {
        self.source = source
        self.orderId = orderId
        self.deviceId = deviceId
        self.imageType = imageType
        self.baseFileName = baseFileName
        self.onSaved = onSaved
        _working = State(initialValue: DeviceImagePhotoEditor.normalized(source))
    }

    private var displayRect: CGRect {
        DeviceImagePhotoEditor.fittedRect(image: working, in: containerSize)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                editorCanvas
            }
            .background(Color(.systemGray6))
            .navigationTitle("Edit Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await saveToOrder() }
                    } label: {
                        if isUploading { ProgressView() } else { Text("Save").bold() }
                    }
                    .disabled(isUploading)
                }
            }
        }
        .sheet(isPresented: $showShare) {
            if let shareURL {
                DeviceImageActivityView(activityItems: [shareURL])
            }
        }
    }

    // MARK: - Canvas

    private var editorCanvas: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black

                Image(uiImage: working)
                    .resizable()
                    .frame(width: displayRect.width, height: displayRect.height)
                    .position(x: displayRect.midX, y: displayRect.midY)

                DrawingCanvas(canvasView: $canvasView, toolPicker: toolPicker, isActive: mode == .draw)
                    .frame(width: displayRect.width, height: displayRect.height)
                    .position(x: displayRect.midX, y: displayRect.midY)
                    .allowsHitTesting(mode == .draw)

                if mode != .draw {
                    selectionLayer
                        .frame(width: displayRect.width, height: displayRect.height)
                        .position(x: displayRect.midX, y: displayRect.midY)
                }
            }
            .onAppear { containerSize = geo.size }
            .onChange(of: geo.size) { _, newValue in containerSize = newValue }
        }
    }

    // Drag-to-select overlay used by blur / black-out / crop modes.
    private var selectionLayer: some View {
        Rectangle()
            .fill(Color.white.opacity(0.001))
            .contentShape(Rectangle())
            .overlay {
                if let selection {
                    Rectangle()
                        .path(in: selection)
                        .stroke(Color.yellow, lineWidth: 2)
                    Rectangle()
                        .path(in: selection)
                        .fill(Color.yellow.opacity(0.12))
                }
            }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        let bounds = CGRect(origin: .zero, size: displayRect.size)
                        let rect = CGRect(
                            x: min(value.startLocation.x, value.location.x),
                            y: min(value.startLocation.y, value.location.y),
                            width: abs(value.location.x - value.startLocation.x),
                            height: abs(value.location.y - value.startLocation.y)
                        ).intersection(bounds)
                        selection = rect
                    }
            )
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Tool", selection: $mode) {
                ForEach(EditMode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            .onChange(of: mode) { _, _ in selection = nil }

            if mode != .draw {
                Text(applyHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Button {
                    undo()
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(!canUndo)

                if mode != .draw {
                    Button {
                        applySelection()
                    } label: {
                        Label("Apply", systemImage: "checkmark.circle.fill")
                    }
                    .disabled(selection == nil || (selection?.width ?? 0) < 4)
                }

                Spacer()

                Button {
                    prepareExport()
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(isUploading)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var applyHint: String {
        switch mode {
        case .blur: return "Drag a box over anything to blur, then tap Apply."
        case .blackout: return "Drag a box to black it out, then tap Apply."
        case .crop: return "Drag the area to keep, then tap Apply."
        case .draw: return ""
        }
    }

    private var canUndo: Bool {
        mode == .draw ? (canvasView.undoManager?.canUndo ?? false) : !history.isEmpty
    }

    // MARK: - Actions

    private func undo() {
        if mode == .draw {
            canvasView.undoManager?.undo()
        } else if let previous = history.popLast() {
            working = previous
            selection = nil
        }
    }

    private func applySelection() {
        guard let sel = selection, sel.width >= 4, sel.height >= 4 else { return }
        // Bake any drawing first so pixel edits and strokes stay consistent.
        flattenDrawing()
        history.append(working)

        guard let cg = working.cgImage else { return }
        let factor = CGFloat(cg.width) / max(displayRect.width, 1)
        let pxRect = CGRect(x: sel.minX * factor, y: sel.minY * factor,
                            width: sel.width * factor, height: sel.height * factor).integral

        switch mode {
        case .blur:     working = ImageEditOps.blur(working, pixelRect: pxRect)
        case .blackout: working = ImageEditOps.blackout(working, pixelRect: pxRect)
        case .crop:     working = ImageEditOps.crop(working, pixelRect: pxRect)
        case .draw:     break
        }
        selection = nil
    }

    /// Render current PencilKit strokes into `working` (pixel space) and clear the canvas.
    private func flattenDrawing() {
        guard !canvasView.drawing.strokes.isEmpty, displayRect.width > 0,
              let cg = working.cgImage else { return }
        let px = CGSize(width: cg.width, height: cg.height)
        let factor = CGFloat(cg.width) / max(displayRect.width, 1)
        let strokeImage = canvasView.drawing.image(
            from: CGRect(origin: .zero, size: displayRect.size), scale: factor
        )
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        working = UIGraphicsImageRenderer(size: px, format: format).image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))
            strokeImage.draw(in: CGRect(origin: .zero, size: px))
        }
        canvasView.drawing = PKDrawing()
    }

    /// Produce the final flattened image (drawing baked in).
    private func flattenedResult() -> UIImage {
        flattenDrawing()
        return working
    }

    private func saveToOrder() async {
        errorMessage = nil
        let result = flattenedResult()
        guard let data = ImageCompressor.compress(result) else {
            errorMessage = "Couldn't process the edited photo"; return
        }
        isUploading = true
        defer { isUploading = false }
        let name = editedFileName()
        do {
            _ = try await DeviceImageService().upload(
                image: PlatformImageData(jpegData: data, fileName: name),
                imageType: imageType,
                orderId: orderId,
                deviceId: deviceId
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't save to the order. Please try again."
        }
    }

    private func prepareExport() {
        let result = flattenedResult()
        // Full-quality JPEG for export/share.
        guard let data = result.jpegData(compressionQuality: 0.95) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(editedFileName())
        do {
            try data.write(to: url, options: .atomic)
            shareURL = url
            showShare = true
        } catch {
            errorMessage = "Couldn't prepare the photo to share"
        }
    }

    private func editedFileName() -> String {
        let base = (baseFileName?.isEmpty == false) ? baseFileName! : "device-photo"
        let trimmed = base.hasSuffix(".jpg") ? String(base.dropLast(4)) : base
        return "\(trimmed)_edited.jpg"
    }

    // MARK: - Geometry / orientation helpers

    private static func fittedRect(image: UIImage, in size: CGSize) -> CGRect {
        let iw = image.size.width, ih = image.size.height
        guard iw > 0, ih > 0, size.width > 0, size.height > 0 else { return .zero }
        let scale = min(size.width / iw, size.height / ih)
        let w = iw * scale, h = ih * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// Redraw to `.up` orientation so cgImage pixel coordinates align with the display.
    private static func normalized(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = image.scale
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }
}

// MARK: - PencilKit canvas

private struct DrawingCanvas: UIViewRepresentable {
    @Binding var canvasView: PKCanvasView
    let toolPicker: PKToolPicker
    let isActive: Bool

    func makeUIView(context: Context) -> PKCanvasView {
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        return canvasView
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {
        if isActive {
            toolPicker.setVisible(true, forFirstResponder: uiView)
            toolPicker.addObserver(uiView)
            DispatchQueue.main.async {
                if !uiView.isFirstResponder { uiView.becomeFirstResponder() }
            }
        } else {
            toolPicker.setVisible(false, forFirstResponder: uiView)
            DispatchQueue.main.async {
                if uiView.isFirstResponder { uiView.resignFirstResponder() }
            }
        }
    }
}

// MARK: - Core Image edit operations

enum ImageEditOps {
    /// Blur just the given pixel region (top-left origin) of the image.
    static func blur(_ image: UIImage, pixelRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let px = CGSize(width: cg.width, height: cg.height)
        let radius = max(8, min(px.width, px.height) / 40)
        let blurred = gaussianBlur(cg, radius: radius) ?? image
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))
            ctx.cgContext.saveGState()
            ctx.cgContext.addRect(pixelRect)
            ctx.cgContext.clip()
            blurred.draw(in: CGRect(origin: .zero, size: px))
            ctx.cgContext.restoreGState()
        }
    }

    /// Fill the given pixel region with solid black (redaction).
    static func blackout(_ image: UIImage, pixelRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let px = CGSize(width: cg.width, height: cg.height)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        return UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(pixelRect)
        }
    }

    /// Crop the image to the given pixel region.
    static func crop(_ image: UIImage, pixelRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let region = pixelRect.intersection(bounds).integral
        guard region.width >= 1, region.height >= 1, let cropped = cg.cropping(to: region) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    private static func gaussianBlur(_ cg: CGImage, radius: CGFloat) -> UIImage? {
        let input = CIImage(cgImage: cg).clampedToExtent()
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(radius, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        let extent = CIImage(cgImage: cg).extent
        guard let outCG = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: outCG)
    }
}
#endif
