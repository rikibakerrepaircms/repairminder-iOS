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

/// Property wrapper for `UnknownDefaultable` enum properties on structs that rely on
/// Swift's *synthesized* `Decodable` (rather than a hand-written `init(from:)`).
///
/// `UnknownDefaultable.init(from:)` alone only covers a JSON `null` — the *synthesized*
/// decoder still calls `container.decode(_:forKey:)` for the property, which throws
/// `keyNotFound` if the server omits the key entirely. Wrapping the property in
/// `@DefaultUnknown` plus the `KeyedDecodingContainer.decode` overload below makes the
/// compiler-generated decode call resolve to `decodeIfPresent`, so an ABSENT key falls
/// back to `.unknownFallback` exactly like an explicit `null` does.
@propertyWrapper
struct DefaultUnknown<Value: UnknownDefaultable>: Decodable {
    var wrappedValue: Value

    init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }

    init(from decoder: Decoder) throws {
        wrappedValue = try Value(from: decoder)
    }
}

extension DefaultUnknown: Equatable where Value: Equatable {}
extension DefaultUnknown: Hashable where Value: Hashable {}
extension DefaultUnknown: Sendable where Value: Sendable {}

extension KeyedDecodingContainer {
    /// More specific than the generic `decode(_:forKey:)` Swift's synthesis calls, so
    /// this overload wins whenever the wrapped property's type is `DefaultUnknown<Value>` —
    /// turning a missing key into `.unknownFallback` instead of `keyNotFound`.
    func decode<Value: UnknownDefaultable>(
        _ type: DefaultUnknown<Value>.Type,
        forKey key: Key
    ) throws -> DefaultUnknown<Value> {
        try decodeIfPresent(type, forKey: key) ?? DefaultUnknown(wrappedValue: Value.unknownFallback)
    }
}
