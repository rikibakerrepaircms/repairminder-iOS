//
//  ScannerOverlay.swift
//  Repair Minder
//
//  Created by Claude on 04/02/2026.
//

import SwiftUI

struct ScannerOverlay: View {
    let isScanning: Bool

    private let scanFrameSize: CGFloat = 280
    private let cornerRadius: CGFloat = 20

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Dimmed overlay with cutout
                Color.black.opacity(0.5)
                    .mask(
                        Rectangle()
                            .overlay(
                                RoundedRectangle(cornerRadius: cornerRadius)
                                    .frame(width: scanFrameSize, height: scanFrameSize)
                                    .blendMode(.destinationOut)
                            )
                    )
                    .ignoresSafeArea()

                // Scan frame corners
                ScanFrameCorners(
                    size: scanFrameSize,
                    cornerRadius: cornerRadius,
                    isScanning: isScanning
                )

                // Instructions
                VStack {
                    Spacer()
                        .frame(height: geometry.size.height / 2 + scanFrameSize / 2 + 40)

                    Text(isScanning ? "Point camera at QR code or barcode" : "Setting up camera...")
                        .font(.subheadline)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())

                    Spacer()
                }
            }
        }
    }
}

struct ScanFrameCorners: View {
    let size: CGFloat
    let cornerRadius: CGFloat
    let isScanning: Bool

    private let cornerLength: CGFloat = 30
    private let lineWidth: CGFloat = 4

    private var frameSize: CGFloat {
        cornerLength + cornerRadius
    }

    private var offsetValue: CGFloat {
        size / 2 - cornerLength / 2 - cornerRadius / 2 + lineWidth / 2
    }

    private var lineColor: Color {
        isScanning ? .white : .gray
    }

    var body: some View {
        ZStack {
            topLeftCorner
            topRightCorner
            bottomRightCorner
            bottomLeftCorner
        }
    }

    private var topLeftCorner: some View {
        CornerShape(cornerRadius: cornerRadius, cornerLength: cornerLength)
            .stroke(lineColor, lineWidth: lineWidth)
            .frame(width: frameSize, height: frameSize)
            .offset(x: -offsetValue, y: -offsetValue)
    }

    private var topRightCorner: some View {
        CornerShape(cornerRadius: cornerRadius, cornerLength: cornerLength)
            .stroke(lineColor, lineWidth: lineWidth)
            .frame(width: frameSize, height: frameSize)
            .rotationEffect(.degrees(90))
            .offset(x: offsetValue, y: -offsetValue)
    }

    private var bottomRightCorner: some View {
        CornerShape(cornerRadius: cornerRadius, cornerLength: cornerLength)
            .stroke(lineColor, lineWidth: lineWidth)
            .frame(width: frameSize, height: frameSize)
            .rotationEffect(.degrees(180))
            .offset(x: offsetValue, y: offsetValue)
    }

    private var bottomLeftCorner: some View {
        CornerShape(cornerRadius: cornerRadius, cornerLength: cornerLength)
            .stroke(lineColor, lineWidth: lineWidth)
            .frame(width: frameSize, height: frameSize)
            .rotationEffect(.degrees(270))
            .offset(x: -offsetValue, y: offsetValue)
    }
}

struct CornerShape: Shape {
    let cornerRadius: CGFloat
    let cornerLength: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()

        // Start from bottom of vertical line
        path.move(to: CGPoint(x: 0, y: cornerLength + cornerRadius))

        // Vertical line up
        path.addLine(to: CGPoint(x: 0, y: cornerRadius))

        // Arc to horizontal
        path.addArc(
            center: CGPoint(x: cornerRadius, y: cornerRadius),
            radius: cornerRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )

        // Horizontal line
        path.addLine(to: CGPoint(x: cornerLength + cornerRadius, y: 0))

        return path
    }
}

#Preview {
    ZStack {
        Color.blue
        ScannerOverlay(isScanning: true)
    }
}
