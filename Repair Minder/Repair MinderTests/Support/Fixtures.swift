//
//  Fixtures.swift
//  Repair MinderTests
//

import Foundation

/// Captured production payloads, scrubbed of personal data by
/// `scripts/scrub-fixture.mjs`.
///
/// Real shapes are the point. A hand-written JSON literal only ever contains
/// what its author remembered to include, which is exactly the rows that never
/// break - the staff Orders page went down on 2026-07-25 to a row no
/// hand-written fixture would have thought to write.
///
/// Located by `#filePath` rather than a bundle resource, so the JSON needs no
/// Xcode target membership and cannot silently go missing from a copy phase.
enum Fixtures {
    static let all = ["orders", "devices", "tickets", "clients"]

    static func url(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()          // Support/
            .deletingLastPathComponent()          // Repair MinderTests/
            .appendingPathComponent("Fixtures")
            .appendingPathComponent("\(name).json")
    }

    static func data(_ name: String) throws -> Data {
        try Data(contentsOf: url(name))
    }
}
