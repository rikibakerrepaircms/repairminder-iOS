import XCTest
@testable import Repair_Minder

final class MultipartFormBodyTests: XCTestCase {

    func testBodyContainsFieldsAndFilePart() throws {
        let boundary = "TESTBOUNDARY"
        let fileData = Data([0xFF, 0xD8, 0xFF, 0x00])
        let body = buildMultipartFormBody(
            boundary: boundary,
            fields: ["image_type": "pre_repair"],
            fileFieldName: "file",
            fileName: "photo.jpg",
            mimeType: "image/jpeg",
            fileData: fileData
        )
        let text = String(decoding: body, as: UTF8.self)

        XCTAssertTrue(text.contains("--\(boundary)\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"image_type\"\r\n\r\npre_repair\r\n"))
        XCTAssertTrue(text.contains("Content-Disposition: form-data; name=\"file\"; filename=\"photo.jpg\"\r\n"))
        XCTAssertTrue(text.contains("Content-Type: image/jpeg\r\n"))
        XCTAssertTrue(text.hasSuffix("--\(boundary)--\r\n"))
    }

    func testFileBytesArePresent() throws {
        let boundary = "B"
        let fileData = Data([0x01, 0x02, 0x03])
        let body = buildMultipartFormBody(
            boundary: boundary, fields: [:],
            fileFieldName: "file", fileName: "x.jpg",
            mimeType: "image/jpeg", fileData: fileData
        )
        XCTAssertTrue(body.range(of: fileData) != nil)
    }
}
