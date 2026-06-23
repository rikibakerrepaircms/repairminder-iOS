//
//  FlexibleDecoding.swift
//  Repair Minder
//
//  Tolerant value wrappers for fields the API may send as either Int or String,
//  or Bool as Int(0/1). Consolidated here so all models share one definition.
//

import Foundation

/// Decodes a value that may be Int or String into a String.
struct FlexibleString: Codable, Equatable, Sendable, Hashable {
    let value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let stringValue = try? container.decode(String.self) {
            value = stringValue
        } else if let intValue = try? container.decode(Int.self) {
            value = String(intValue)
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }

    /// Direct initializer for use in previews and tests.
    init(_ value: String) {
        self.value = value
    }
}

/// Decodes a value that may be Int (0/1) or Bool into a Bool.
struct FlexibleBool: Decodable, Sendable, Equatable {
    let value: Bool

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            value = intValue != 0
        } else if let boolValue = try? container.decode(Bool.self) {
            value = boolValue
        } else {
            value = true
        }
    }

    init(_ value: Bool) {
        self.value = value
    }
}
