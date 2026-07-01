import XCTest
@testable import Repair_Minder

#if os(iOS)
import UIKit

final class ImageCompressorTests: XCTestCase {

    /// Draw a large noisy image so it is well above the size/px limits and can't JPEG to near-zero.
    private func makeLargeImage() -> UIImage {
        let size = CGSize(width: 4000, height: 3000)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.systemBlue.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            for i in stride(from: 0, to: 4000, by: 40) {
                UIColor(hue: CGFloat(i % 360) / 360, saturation: 1, brightness: 1, alpha: 1).setFill()
                ctx.fill(CGRect(x: i, y: 0, width: 20, height: 3000))
            }
        }
    }

    func testCompressesUnder150KB() throws {
        let data = try XCTUnwrap(ImageCompressor.compress(makeLargeImage()))
        XCTAssertLessThanOrEqual(data.count, 150 * 1024, "compressed size should be <= 150KB")
    }

    func testResizesLongestSideTo1024() throws {
        let data = try XCTUnwrap(ImageCompressor.compress(makeLargeImage()))
        let out = try XCTUnwrap(UIImage(data: data))
        let longest = max(out.size.width * out.scale, out.size.height * out.scale)
        XCTAssertLessThanOrEqual(longest, 1024, "longest side should be <= 1024px")
    }

    func testOutputIsValidJPEG() throws {
        let data = try XCTUnwrap(ImageCompressor.compress(makeLargeImage()))
        XCTAssertEqual(Array(data.prefix(3)), [0xFF, 0xD8, 0xFF])
    }
}
#endif
