import XCTest
@testable import Repair_Minder

final class DeviceImageModelsTests: XCTestCase {

    private func decoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    func testDecodesListItem() throws {
        let json = """
        {
          "id": "img1",
          "image_type": "pre_repair",
          "url": "https://api.repairminder.com/api/orders/o1/devices/d1/images/img1/file",
          "filename": "photo.jpg",
          "size_bytes": 145234,
          "caption": null,
          "sort_order": 1719858600000,
          "uploaded_at": "2026-07-01T14:30:00Z",
          "uploaded_by": { "id": "u1", "name": "Jane Tech" }
        }
        """.data(using: .utf8)!

        let item = try decoder().decode(DeviceImageListItem.self, from: json)
        XCTAssertEqual(item.id, "img1")
        XCTAssertTrue(item.isPreRepair)
        XCTAssertEqual(item.uploadedBy?.name, "Jane Tech")
    }

    func testDecodesListItemWithNullUploader() throws {
        let json = """
        { "id": "img2", "image_type": "post_repair", "url": "u", "filename": null,
          "size_bytes": 100, "caption": "after", "sort_order": 1, "uploaded_at": "t",
          "uploaded_by": null }
        """.data(using: .utf8)!
        let item = try decoder().decode(DeviceImageListItem.self, from: json)
        XCTAssertTrue(item.isPostRepair)
        XCTAssertNil(item.uploadedBy)
    }

    func testDecodesUploadResult() throws {
        let json = """
        { "id": "img3", "url": "u", "filename": "p.jpg", "content_type": "image/jpeg",
          "size_bytes": 999, "image_type": "pre_repair", "caption": null }
        """.data(using: .utf8)!
        let result = try decoder().decode(DeviceImageUploadResult.self, from: json)
        XCTAssertEqual(result.id, "img3")
        XCTAssertEqual(result.imageType, "pre_repair")
    }
}
