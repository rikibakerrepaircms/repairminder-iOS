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
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self.unknownFallback
    }
}
