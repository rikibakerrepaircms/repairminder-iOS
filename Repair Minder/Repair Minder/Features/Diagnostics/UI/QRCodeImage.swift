// Features/Diagnostics/UI/QRCodeImage.swift
// Local QR code generator — lets a technician display a scannable QR on-screen
// so a second device can open the camera-test target page without typing a URL.
import SwiftUI
#if canImport(UIKit)
import UIKit
import CoreImage.CIFilterBuiltins

/// Renders a string as a QR code UIImage.
enum QRCodeMaker {
    static func image(from string: String, scale: CGFloat = 8) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        guard let output = filter.outputImage?
            .transformed(by: CGAffineTransform(scaleX: scale, y: scale)) else { return nil }
        let context = CIContext()
        guard let cg = context.createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cg)
    }
}

/// SwiftUI wrapper that shows a QR code for `string`, or nothing if generation fails.
struct QRCodeImage: View {
    let string: String
    var side: CGFloat = 120
    var body: some View {
        if let ui = QRCodeMaker.image(from: string) {
            Image(uiImage: ui)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: side, height: side)
        } else {
            VStack(spacing: 6) {
                Image(systemName: "qrcode")
                    .font(.system(size: side * 0.35))
                    .foregroundStyle(.secondary)
                Text("QR unavailable")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(width: side, height: side)
        }
    }
}
#endif
