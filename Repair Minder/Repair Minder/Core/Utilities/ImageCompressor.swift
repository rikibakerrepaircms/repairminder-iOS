//
//  ImageCompressor.swift
//  Repair Minder
//
//  Client-side image compression mirroring the web app's
//  browser-image-compression settings: JPEG, longest side <= 1024px,
//  quality ~0.6, target <= 150KB. Keeps R2 storage small while
//  preserving acceptable quality.
//

#if os(iOS)
import UIKit

enum ImageCompressor {

    static let maxDimension: CGFloat = 1024
    static let maxBytes = 150 * 1024
    static let qualitySteps: [CGFloat] = [0.6, 0.5, 0.4, 0.3]

    /// Resize + JPEG-encode. Returns nil only if encoding fails entirely.
    static func compress(_ image: UIImage) -> Data? {
        let resized = resize(image, longestSide: maxDimension)
        var data = resized.jpegData(compressionQuality: qualitySteps[0])
        for quality in qualitySteps {
            guard let candidate = resized.jpegData(compressionQuality: quality) else { continue }
            data = candidate
            if candidate.count <= maxBytes { return candidate }
        }
        return data
    }

    /// Scale so the longest side <= `longestSide`, preserving aspect ratio.
    /// Never upscales. Output scale 1 so pixel size == point size.
    private static func resize(_ image: UIImage, longestSide: CGFloat) -> UIImage {
        let pxWidth = image.size.width * image.scale
        let pxHeight = image.size.height * image.scale
        let longest = max(pxWidth, pxHeight)
        guard longest > longestSide else { return image }

        let ratio = longestSide / longest
        let newSize = CGSize(width: (pxWidth * ratio).rounded(),
                             height: (pxHeight * ratio).rounded())

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: newSize, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
#endif
