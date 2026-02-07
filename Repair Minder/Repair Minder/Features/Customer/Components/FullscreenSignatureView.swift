//
//  FullscreenSignatureView.swift
//  Repair Minder
//

import SwiftUI

/// Fullscreen signature canvas that forces landscape on iPhone for maximum drawing area.
struct FullscreenSignatureView: View {
    @Binding var drawnSignature: UIImage?
    @Environment(\.dismiss) private var dismiss

    @State private var currentPath: Path = Path()
    @State private var paths: [Path] = []
    @State private var canvasSize: CGSize = .zero

    private var isPhone: Bool {
        UIDevice.current.userInterfaceIdiom == .phone
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.95)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Toolbar
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    Text("Draw Your Signature")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Spacer()

                    Button {
                        captureAndDismiss()
                    } label: {
                        Text("Done")
                            .fontWeight(.semibold)
                            .foregroundStyle(paths.isEmpty ? .gray : .white)
                    }
                    .disabled(paths.isEmpty)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Canvas area
                GeometryReader { geometry in
                    ZStack {
                        // White canvas background
                        RoundedRectangle(cornerRadius: 12)
                            .fill(.white)

                        // Signature line
                        Rectangle()
                            .fill(Color(.systemGray4))
                            .frame(height: 1)
                            .padding(.horizontal, 40)
                            .offset(y: geometry.size.height * 0.25)

                        // Drawn paths
                        Canvas { context, size in
                            for path in paths {
                                context.stroke(path, with: .color(.black), lineWidth: 2.5)
                            }
                            context.stroke(currentPath, with: .color(.black), lineWidth: 2.5)
                        }
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    let point = value.location
                                    if value.translation == .zero {
                                        currentPath.move(to: point)
                                    } else {
                                        currentPath.addLine(to: point)
                                    }
                                }
                                .onEnded { _ in
                                    paths.append(currentPath)
                                    currentPath = Path()
                                }
                        )

                        // Placeholder
                        if paths.isEmpty {
                            Text("Sign here")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .onAppear { canvasSize = geometry.size }
                    .onChange(of: geometry.size) { _, newSize in canvasSize = newSize }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)

                // Clear button
                HStack {
                    Spacer()
                    Button {
                        paths.removeAll()
                        currentPath = Path()
                    } label: {
                        Label("Clear", systemImage: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.white.opacity(0.15))
                            .clipShape(Capsule())
                    }
                    .disabled(paths.isEmpty)
                    Spacer()
                }
                .padding(.bottom, 12)
            }
        }
        .onAppear {
            if isPhone {
                AppDelegate.orientationLock = .landscape
                requestOrientationUpdate(.landscape)
            }
        }
        .onDisappear {
            if isPhone {
                AppDelegate.orientationLock = .portrait
                requestOrientationUpdate(.portrait)
            }
        }
    }

    private func captureAndDismiss() {
        guard !paths.isEmpty else { return }
        // Capture at canvas size for high quality
        let captureWidth = max(canvasSize.width, 600)
        let captureHeight = max(canvasSize.height, 300)
        let renderer = ImageRenderer(content:
            Canvas { context, size in
                for path in paths {
                    context.stroke(path, with: .color(.black), lineWidth: 2.5)
                }
            }
            .frame(width: captureWidth, height: captureHeight)
            .background(.white)
        )
        renderer.scale = 3.0
        drawnSignature = renderer.uiImage
        dismiss()
    }

    private func requestOrientationUpdate(_ orientations: UIInterfaceOrientationMask) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else { return }
        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: orientations))
        // Trigger the system to re-evaluate supported orientations
        windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

#Preview {
    FullscreenSignatureView(drawnSignature: .constant(nil))
}
