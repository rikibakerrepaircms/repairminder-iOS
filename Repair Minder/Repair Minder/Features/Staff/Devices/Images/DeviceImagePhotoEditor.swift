//
//  DeviceImagePhotoEditor.swift
//  Repair Minder
//
//  Basic photo editor for device images:
//   • Draw   — PencilKit pen/pencil/marker + stroke eraser + undo.
//   • Blur / Black-out — redact a region either by dragging a Box or by
//     painting freehand with a size-adjustable Brush.
//   • Crop   — rule-of-thirds grid, draggable crop rectangle, 90° rotate
//     buttons and a straighten slider (any angle).
//  The result can be exported (share sheet) or saved back to the order as a
//  new photo. iOS only.
//
//  Note: Apple's generative "Clean Up" object removal has no third-party API,
//  so redaction is blur / black-out. If a public API ships, an "AI Erase"
//  mode can be added alongside these.
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
    let baseFileName: String?
    var onSaved: () -> Void = {}

    @Environment(\.dismiss) private var dismiss

    @State private var working: UIImage
    @State private var history: [UIImage] = []              // undo stack for destructive ops
    @State private var canvasView = PKCanvasView()
    @State private var toolPicker = PKToolPicker()

    @State private var mode: EditMode = .draw
    @State private var redactStyle: RedactStyle = .box
    @State private var brushRadius: CGFloat = 22

    @State private var containerSize: CGSize = .zero
    @State private var selection: CGRect?                   // box, in displayRect-local points
    @State private var currentStroke: [CGPoint] = []        // active brush stroke, displayRect-local

    // Crop
    @State private var rotationDegrees: Double = 0
    @State private var rotatedPreview: UIImage?
    @State private var cropRect: CGRect?                    // in cropDisplayRect-local points

    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var shareURL: URL?
    @State private var showShare = false

    private let maxEditorDimension: CGFloat = 2048

    enum EditMode: String, CaseIterable, Identifiable {
        case draw = "Draw", blur = "Blur", blackout = "Black-out", crop = "Crop"
        var id: String { rawValue }
    }
    enum RedactStyle: String, CaseIterable, Identifiable {
        case box = "Box", brush = "Brush"
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
        let prepared = DeviceImagePhotoEditor.prepare(source, maxDimension: 2048)
        _working = State(initialValue: prepared)
    }

    private var displayRect: CGRect {
        DeviceImagePhotoEditor.fittedRect(image: working, in: containerSize)
    }
    private var cropDisplayRect: CGRect {
        DeviceImagePhotoEditor.fittedRect(image: rotatedPreview ?? working, in: containerSize)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                controls
                canvasArea
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
            if let shareURL { DeviceImageActivityView(activityItems: [shareURL]) }
        }
        .onChange(of: mode) { _, newMode in
            selection = nil
            currentStroke = []
            if newMode == .crop { enterCrop() }
        }
        .onChange(of: rotationDegrees) { _, _ in refreshRotatedPreview() }
    }

    // MARK: - Canvas area

    private var canvasArea: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Color.black

                if mode == .crop {
                    cropArea
                } else {
                    Image(uiImage: working)
                        .resizable()
                        .frame(width: displayRect.width, height: displayRect.height)
                        .position(x: displayRect.midX, y: displayRect.midY)

                    DrawingCanvas(canvasView: $canvasView, toolPicker: toolPicker, isActive: mode == .draw)
                        .frame(width: displayRect.width, height: displayRect.height)
                        .position(x: displayRect.midX, y: displayRect.midY)
                        .allowsHitTesting(mode == .draw)

                    if mode == .blur || mode == .blackout {
                        redactOverlay
                            .frame(width: displayRect.width, height: displayRect.height)
                            .position(x: displayRect.midX, y: displayRect.midY)
                    }
                }
            }
            .onAppear { containerSize = geo.size }
            .onChange(of: geo.size) { _, s in containerSize = s }
        }
    }

    // MARK: - Redact overlay (box + brush)

    private var redactOverlay: some View {
        ZStack {
            if redactStyle == .box, let selection {
                Rectangle().path(in: selection).fill(Color.yellow.opacity(0.15))
                Rectangle().path(in: selection).stroke(Color.yellow, lineWidth: 2)
            }
            if redactStyle == .brush, !currentStroke.isEmpty {
                BrushStrokeShape(points: currentStroke)
                    .stroke(
                        (mode == .blackout ? Color.black : Color.yellow).opacity(0.5),
                        style: StrokeStyle(lineWidth: brushRadius * 2, lineCap: .round, lineJoin: .round)
                    )
            }
        }
        .contentShape(Rectangle())
        .gesture(redactGesture)
    }

    private var redactGesture: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                let bounds = CGRect(origin: .zero, size: displayRect.size)
                let p = clamp(value.location, to: bounds)
                if redactStyle == .box {
                    selection = CGRect(
                        x: min(value.startLocation.x, value.location.x),
                        y: min(value.startLocation.y, value.location.y),
                        width: abs(value.location.x - value.startLocation.x),
                        height: abs(value.location.y - value.startLocation.y)
                    ).intersection(bounds)
                } else {
                    currentStroke.append(p)
                }
            }
            .onEnded { _ in
                if redactStyle == .brush {
                    bakeBrushStroke(currentStroke)
                    currentStroke = []
                }
            }
    }

    // MARK: - Crop area

    private var cropArea: some View {
        ZStack {
            Image(uiImage: rotatedPreview ?? working)
                .resizable()
                .frame(width: cropDisplayRect.width, height: cropDisplayRect.height)
                .position(x: cropDisplayRect.midX, y: cropDisplayRect.midY)

            CropOverlay(
                bounds: cropDisplayRect.size,
                rect: Binding(
                    get: { cropRect ?? CGRect(origin: .zero, size: cropDisplayRect.size) },
                    set: { cropRect = $0 }
                )
            )
            .frame(width: cropDisplayRect.width, height: cropDisplayRect.height)
            .position(x: cropDisplayRect.midX, y: cropDisplayRect.midY)
        }
    }

    // MARK: - Controls

    private var controls: some View {
        VStack(spacing: 10) {
            Picker("Tool", selection: $mode) {
                ForEach(EditMode.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)

            if mode == .blur || mode == .blackout { redactControls }
            if mode == .crop { cropControls }
            if mode == .blur || mode == .blackout {
                Text(redactHint).font(.caption).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            HStack(spacing: 16) {
                Button { undo() } label: { Label("Undo", systemImage: "arrow.uturn.backward") }
                    .disabled(!canUndo)
                Spacer()
                Button { prepareExport() } label: { Label("Export", systemImage: "square.and.arrow.up") }
                    .disabled(isUploading)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    private var redactControls: some View {
        VStack(spacing: 8) {
            HStack {
                Picker("Style", selection: $redactStyle) {
                    ForEach(RedactStyle.allCases) { s in Text(s.rawValue).tag(s) }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 200)

                if redactStyle == .box {
                    Spacer()
                    Button { applyBox() } label: { Label("Apply", systemImage: "checkmark.circle.fill") }
                        .disabled((selection?.width ?? 0) < 4)
                }
            }
            if redactStyle == .brush {
                HStack(spacing: 10) {
                    Image(systemName: "paintbrush.pointed").font(.caption)
                    Slider(value: $brushRadius, in: 8...80)
                    Circle().fill(.secondary)
                        .frame(width: min(brushRadius, 34), height: min(brushRadius, 34))
                        .frame(width: 34, height: 34)
                }
            }
        }
    }

    private var cropControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                Button { rotate90(-90) } label: { Image(systemName: "rotate.left") }
                HStack(spacing: 6) {
                    Image(systemName: "slider.horizontal.below.rectangle").font(.caption)
                    Slider(value: $rotationDegrees, in: -45...45, step: 0.5)
                    Text("\(Int(rotationDegrees.rounded()))°").font(.caption.monospacedDigit()).frame(width: 38)
                }
                Button { rotate90(90) } label: { Image(systemName: "rotate.right") }
            }
            Button { applyCrop() } label: {
                Label("Apply Crop", systemImage: "crop").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var redactHint: String {
        if redactStyle == .brush {
            return mode == .blur ? "Paint over anything to blur it." : "Paint over anything to black it out."
        }
        return mode == .blur ? "Drag a box to blur, then Apply." : "Drag a box to black out, then Apply."
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
            if mode == .crop { refreshRotatedPreview() }
        }
    }

    private func enterCrop() {
        rotationDegrees = 0
        cropRect = nil
        refreshRotatedPreview()
    }

    private func refreshRotatedPreview() {
        guard mode == .crop else { return }
        flattenDrawing()
        rotatedPreview = ImageEditOps.rotate(working, degrees: CGFloat(rotationDegrees))
        cropRect = nil  // reset selection to full when the rotated frame changes
    }

    private func rotate90(_ delta: Double) {
        rotationDegrees = (rotationDegrees + delta)
        if rotationDegrees > 180 { rotationDegrees -= 360 }
        if rotationDegrees < -180 { rotationDegrees += 360 }
    }

    private func applyBox() {
        guard let sel = selection, sel.width >= 4, sel.height >= 4 else { return }
        flattenDrawing()
        history.append(working)
        guard let cg = working.cgImage else { return }
        let factor = CGFloat(cg.width) / max(displayRect.width, 1)
        let pxRect = CGRect(x: sel.minX * factor, y: sel.minY * factor,
                            width: sel.width * factor, height: sel.height * factor).integral
        working = (mode == .blur)
            ? ImageEditOps.blur(working, pixelRect: pxRect)
            : ImageEditOps.blackout(working, pixelRect: pxRect)
        selection = nil
    }

    private func bakeBrushStroke(_ points: [CGPoint]) {
        guard !points.isEmpty, let cg = working.cgImage else { return }
        flattenDrawing()
        history.append(working)
        let px = CGSize(width: cg.width, height: cg.height)
        let factor = CGFloat(cg.width) / max(displayRect.width, 1)
        let widthPx = brushRadius * 2 * factor
        let scaled = points.map { CGPoint(x: $0.x * factor, y: $0.y * factor) }

        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        working = UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            let c = ctx.cgContext
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))

            let path = CGMutablePath()
            if scaled.count == 1 {
                let r = widthPx / 2
                path.addEllipse(in: CGRect(x: scaled[0].x - r, y: scaled[0].y - r, width: widthPx, height: widthPx))
                if mode == .blackout {
                    c.setFillColor(UIColor.black.cgColor); c.addPath(path); c.fillPath()
                } else {
                    c.addPath(path); c.clip()
                    (ImageEditOps.gaussianBlurImage(cg) ?? UIImage(cgImage: cg)).draw(in: CGRect(origin: .zero, size: px))
                }
            } else {
                path.addLines(between: scaled)
                if mode == .blackout {
                    c.setStrokeColor(UIColor.black.cgColor)
                    c.setLineWidth(widthPx); c.setLineCap(.round); c.setLineJoin(.round)
                    c.addPath(path); c.strokePath()
                } else {
                    let outline = path.copy(strokingWithWidth: widthPx, lineCap: .round, lineJoin: .round, miterLimit: 0)
                    c.addPath(outline); c.clip()
                    (ImageEditOps.gaussianBlurImage(cg) ?? UIImage(cgImage: cg)).draw(in: CGRect(origin: .zero, size: px))
                }
            }
        }
    }

    private func applyCrop() {
        let base = rotatedPreview ?? working
        guard let cg = base.cgImage else { return }
        let rect = cropRect ?? CGRect(origin: .zero, size: cropDisplayRect.size)
        let factor = CGFloat(cg.width) / max(cropDisplayRect.width, 1)
        let pxRect = CGRect(x: rect.minX * factor, y: rect.minY * factor,
                            width: rect.width * factor, height: rect.height * factor).integral
        history.append(working)
        working = ImageEditOps.crop(base, pixelRect: pxRect)
        rotationDegrees = 0
        rotatedPreview = nil
        cropRect = nil
        mode = .draw
    }

    private func flattenDrawing() {
        guard !canvasView.drawing.strokes.isEmpty, displayRect.width > 0, let cg = working.cgImage else { return }
        let px = CGSize(width: cg.width, height: cg.height)
        let factor = CGFloat(cg.width) / max(displayRect.width, 1)
        let strokeImage = canvasView.drawing.image(from: CGRect(origin: .zero, size: displayRect.size), scale: factor)
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        working = UIGraphicsImageRenderer(size: px, format: format).image { _ in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))
            strokeImage.draw(in: CGRect(origin: .zero, size: px))
        }
        canvasView.drawing = PKDrawing()
    }

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
        do {
            _ = try await DeviceImageService().upload(
                image: PlatformImageData(jpegData: data, fileName: editedFileName()),
                imageType: imageType, orderId: orderId, deviceId: deviceId
            )
            onSaved()
            dismiss()
        } catch {
            errorMessage = "Couldn't save to the order. Please try again."
        }
    }

    private func prepareExport() {
        let result = flattenedResult()
        guard let data = result.jpegData(compressionQuality: 0.95) else { return }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(editedFileName())
        do {
            try data.write(to: url, options: .atomic)
            shareURL = url; showShare = true
        } catch {
            errorMessage = "Couldn't prepare the photo to share"
        }
    }

    private func editedFileName() -> String {
        let base = (baseFileName?.isEmpty == false) ? baseFileName! : "device-photo"
        let trimmed = base.hasSuffix(".jpg") ? String(base.dropLast(4)) : base
        return "\(trimmed)_edited.jpg"
    }

    private func clamp(_ p: CGPoint, to rect: CGRect) -> CGPoint {
        CGPoint(x: min(max(p.x, rect.minX), rect.maxX), y: min(max(p.y, rect.minY), rect.maxY))
    }

    // MARK: - Geometry / prep helpers

    private static func fittedRect(image: UIImage, in size: CGSize) -> CGRect {
        let iw = image.size.width, ih = image.size.height
        guard iw > 0, ih > 0, size.width > 0, size.height > 0 else { return .zero }
        let scale = min(size.width / iw, size.height / ih)
        let w = iw * scale, h = ih * scale
        return CGRect(x: (size.width - w) / 2, y: (size.height - h) / 2, width: w, height: h)
    }

    /// Normalise orientation to `.up` and cap the longest side for smooth editing.
    private static func prepare(_ image: UIImage, maxDimension: CGFloat) -> UIImage {
        let pxW = image.size.width * image.scale
        let pxH = image.size.height * image.scale
        let longest = max(pxW, pxH)
        let ratio = longest > maxDimension ? maxDimension / longest : 1
        let target = CGSize(width: (pxW * ratio).rounded(), height: (pxH * ratio).rounded())
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}

// MARK: - Brush stroke preview shape

private struct BrushStrokeShape: Shape {
    let points: [CGPoint]
    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for p in points.dropFirst() { path.addLine(to: p) }
        if points.count == 1 { path.addLine(to: CGPoint(x: first.x + 0.1, y: first.y)) }
        return path
    }
}

// MARK: - Crop overlay (grid + draggable rectangle)

private struct CropOverlay: View {
    let bounds: CGSize
    @Binding var rect: CGRect

    private let handle: CGFloat = 22
    private let minSize: CGFloat = 60

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Dim outside the crop rect.
            Color.black.opacity(0.45)
                .mask {
                    ZStack {
                        Rectangle()
                        Rectangle().path(in: rect).fill(style: FillStyle(eoFill: true)).blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
                .allowsHitTesting(false)

            // Rule-of-thirds grid + border.
            gridPath.stroke(Color.white.opacity(0.9), lineWidth: 1)
            Rectangle().path(in: rect).stroke(Color.white, lineWidth: 2)

            // Move the whole rect.
            Color.clear
                .contentShape(Rectangle())
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            var r = rect
                            r.origin.x = clamp(rect.minX + v.translation.width, 0, bounds.width - rect.width)
                            r.origin.y = clamp(rect.minY + v.translation.height, 0, bounds.height - rect.height)
                            rect = r
                        }
                )

            ForEach(Corner.allCases, id: \.self) { corner in
                handleView(corner)
            }
        }
        .frame(width: bounds.width, height: bounds.height, alignment: .topLeading)
    }

    private var gridPath: Path {
        var p = Path()
        for i in 1...2 {
            let x = rect.minX + rect.width * CGFloat(i) / 3
            p.move(to: CGPoint(x: x, y: rect.minY)); p.addLine(to: CGPoint(x: x, y: rect.maxY))
            let y = rect.minY + rect.height * CGFloat(i) / 3
            p.move(to: CGPoint(x: rect.minX, y: y)); p.addLine(to: CGPoint(x: rect.maxX, y: y))
        }
        return p
    }

    private func handleView(_ corner: Corner) -> some View {
        let point = corner.point(in: rect)
        return Circle()
            .fill(Color.white)
            .frame(width: handle, height: handle)
            .position(point)
            .gesture(
                DragGesture()
                    .onChanged { v in rect = corner.resized(rect, to: v.location, bounds: bounds, minSize: minSize) }
            )
    }

    private func clamp(_ x: CGFloat, _ lo: CGFloat, _ hi: CGFloat) -> CGFloat { min(max(x, lo), max(lo, hi)) }

    enum Corner: CaseIterable {
        case topLeft, topRight, bottomLeft, bottomRight
        func point(in r: CGRect) -> CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: r.minX, y: r.minY)
            case .topRight: return CGPoint(x: r.maxX, y: r.minY)
            case .bottomLeft: return CGPoint(x: r.minX, y: r.maxY)
            case .bottomRight: return CGPoint(x: r.maxX, y: r.maxY)
            }
        }
        func resized(_ r: CGRect, to loc: CGPoint, bounds: CGSize, minSize: CGFloat) -> CGRect {
            let x = min(max(loc.x, 0), bounds.width)
            let y = min(max(loc.y, 0), bounds.height)
            var minX = r.minX, minY = r.minY, maxX = r.maxX, maxY = r.maxY
            switch self {
            case .topLeft: minX = min(x, maxX - minSize); minY = min(y, maxY - minSize)
            case .topRight: maxX = max(x, minX + minSize); minY = min(y, maxY - minSize)
            case .bottomLeft: minX = min(x, maxX - minSize); maxY = max(y, minY + minSize)
            case .bottomRight: maxX = max(x, minX + minSize); maxY = max(y, minY + minSize)
            }
            return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
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
            DispatchQueue.main.async { if !uiView.isFirstResponder { uiView.becomeFirstResponder() } }
        } else {
            toolPicker.setVisible(false, forFirstResponder: uiView)
            DispatchQueue.main.async { if uiView.isFirstResponder { uiView.resignFirstResponder() } }
        }
    }
}

// MARK: - Core Image edit operations

enum ImageEditOps {
    static func blur(_ image: UIImage, pixelRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let px = CGSize(width: cg.width, height: cg.height)
        let blurred = gaussianBlurImage(cg) ?? image
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        return UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))
            ctx.cgContext.saveGState()
            ctx.cgContext.addRect(pixelRect); ctx.cgContext.clip()
            blurred.draw(in: CGRect(origin: .zero, size: px))
            ctx.cgContext.restoreGState()
        }
    }

    static func blackout(_ image: UIImage, pixelRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let px = CGSize(width: cg.width, height: cg.height)
        let format = UIGraphicsImageRendererFormat.default(); format.scale = 1
        return UIGraphicsImageRenderer(size: px, format: format).image { ctx in
            UIImage(cgImage: cg).draw(in: CGRect(origin: .zero, size: px))
            ctx.cgContext.setFillColor(UIColor.black.cgColor)
            ctx.cgContext.fill(pixelRect)
        }
    }

    static func crop(_ image: UIImage, pixelRect: CGRect) -> UIImage {
        guard let cg = image.cgImage else { return image }
        let bounds = CGRect(x: 0, y: 0, width: cg.width, height: cg.height)
        let region = pixelRect.intersection(bounds).integral
        guard region.width >= 1, region.height >= 1, let cropped = cg.cropping(to: region) else { return image }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: .up)
    }

    /// Rotate by any angle, growing the canvas and filling gaps with white.
    static func rotate(_ image: UIImage, degrees: CGFloat) -> UIImage {
        let radians = degrees * .pi / 180
        guard abs(degrees).truncatingRemainder(dividingBy: 360) != 0 else { return image }
        let size = image.size
        let newSize = CGRect(origin: .zero, size: size)
            .applying(CGAffineTransform(rotationAngle: radians)).integral.size
        let format = UIGraphicsImageRendererFormat.default(); format.scale = image.scale
        return UIGraphicsImageRenderer(size: newSize, format: format).image { ctx in
            let c = ctx.cgContext
            c.setFillColor(UIColor.white.cgColor)
            c.fill(CGRect(origin: .zero, size: newSize))
            c.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            c.rotate(by: radians)
            image.draw(in: CGRect(x: -size.width / 2, y: -size.height / 2, width: size.width, height: size.height))
        }
    }

    static func gaussianBlurImage(_ cg: CGImage, radius: CGFloat? = nil) -> UIImage? {
        let r = radius ?? max(8, CGFloat(min(cg.width, cg.height)) / 40)
        let input = CIImage(cgImage: cg).clampedToExtent()
        guard let filter = CIFilter(name: "CIGaussianBlur") else { return nil }
        filter.setValue(input, forKey: kCIInputImageKey)
        filter.setValue(r, forKey: kCIInputRadiusKey)
        guard let output = filter.outputImage else { return nil }
        let context = CIContext(options: nil)
        let extent = CIImage(cgImage: cg).extent
        guard let outCG = context.createCGImage(output, from: extent) else { return nil }
        return UIImage(cgImage: outCG)
    }
}
#endif
