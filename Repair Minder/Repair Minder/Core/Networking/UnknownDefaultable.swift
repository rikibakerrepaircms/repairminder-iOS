//
//  UnknownDefaultable.swift
//  Repair Minder
//
//  Lets a String-backed enum decode an unrecognised server value to a designated
//  `.unknown` case instead of throwing and blanking the whole screen.
//

import Foundation

protocol UnknownDefaultable: RawRepresentable, Decodable where RawValue == String {
    /// The case used when the server sends a value this enum doesn't know.
    static var unknownFallback: Self { get }
}

extension UnknownDefaultable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        // A JSON `null` (e.g. a nullable DB column with no server-side backfill)
        // must fall back to `.unknown` rather than throw — otherwise a single
        // bad row poisons the decode of an entire array.
        if container.decodeNil() {
            self = Self.unknownFallback
            return
        }
        let raw = try container.decode(String.self)
        self = Self(rawValue: raw) ?? Self.unknownFallback
    }
}
