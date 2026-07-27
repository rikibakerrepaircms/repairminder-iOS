//
//  FixturePrivacyTests.swift
//  Repair MinderTests
//

import Testing
import Foundation

/// This repo is pushed to GitHub. The fixtures are captured production
/// responses, so `scripts/scrub-fixture.mjs` is a privacy control and these
/// tests prove it ran rather than trusting that it did.
///
/// They are not theoretical. The first scrub of these four files left 16 real
/// email addresses and two real mobile numbers behind, because they were
/// embedded in free-text `notes[].body` prose rather than in a field the
/// key-based pass knew to look at. These assertions are what caught it.
struct FixturePrivacyTests {

    private func strings(_ any: Any, into out: inout [String]) {
        if let s = any as? String { out.append(s) }
        else if let a = any as? [Any] { a.forEach { strings($0, into: &out) } }
        else if let d = any as? [String: Any] { d.values.forEach { strings($0, into: &out) } }
    }

    private func allStrings(_ name: String) throws -> [String] {
        let json = try JSONSerialization.jsonObject(with: Fixtures.data(name))
        var out: [String] = []
        strings(json, into: &out)
        return out
    }

    /// Anything shaped like an address must be at the RFC 2606 reserved domain
    /// the scrubber owns, which can never route to a real person.
    @Test func noRealEmailAddresses() throws {
        let pattern = try NSRegularExpression(pattern: #"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}"#)
        for name in Fixtures.all {
            for s in try allStrings(name) {
                let range = NSRange(s.startIndex..., in: s)
                for m in pattern.matches(in: s, range: range) {
                    let hit = String(s[Range(m.range, in: s)!])
                    #expect(hit.hasSuffix("@example.invalid"),
                            "\(name).json leaks an email address: \(hit)")
                }
            }
        }
    }

    /// UK mobile and landline shapes. 07700900000 is Ofcom's reserved drama
    /// range and is the only number the scrubber emits.
    @Test func noRealPhoneNumbers() throws {
        let pattern = try NSRegularExpression(pattern: #"(\+44|\b0)\d{9,10}\b"#)
        for name in Fixtures.all {
            for s in try allStrings(name) {
                let range = NSRange(s.startIndex..., in: s)
                for m in pattern.matches(in: s, range: range) {
                    let hit = String(s[Range(m.range, in: s)!])
                    #expect(hit == "07700900000",
                            "\(name).json leaks a phone number: \(hit)")
                }
            }
        }
    }

    /// A postcode identifies a household, so it is personal data even with no
    /// name beside it.
    ///
    /// This assertion exists because the first three rounds of scrubbing all
    /// missed them: they sat in free-text note bodies, reachable by neither the
    /// key pass nor the name map, exactly like the emails and phone numbers
    /// before them. Six real customer postcodes were in the fixtures and every
    /// test was green.
    ///
    /// `S20FE` is allowed: it is a Samsung Galaxy S20 FE and parses perfectly
    /// as the postcode S2 0FE. The scrubber resolves that ambiguity from the
    /// payload's own device catalogue rather than from a regex.
    @Test func noRealPostcodes() throws {
        let pattern = try NSRegularExpression(pattern: #"\b[A-Z]{1,2}[0-9][0-9A-Z]? ?[0-9][A-Z]{2}\b"#)
        let allowed: Set<String> = ["AA1 1AA", "S20FE"]
        for name in Fixtures.all {
            for s in try allStrings(name) {
                let range = NSRange(s.startIndex..., in: s)
                for m in pattern.matches(in: s, range: range) {
                    let hit = String(s[Range(m.range, in: s)!])
                    #expect(allowed.contains(hit),
                            "\(name).json leaks a postcode: \(hit)")
                }
            }
        }
    }

    /// A fixture with no rows would pass every decode test in Task 4
    /// vacuously, which is worse than having no test at all.
    @Test func fixturesAreNotEmpty() throws {
        for name in Fixtures.all {
            #expect(try Fixtures.data(name).count > 1_000, "\(name).json looks empty")
        }
    }

    // The scrubber's synthetic vocabulary. Any name-shaped value in a fixture
    // must be built from these, so a real one stands out immediately.
    private static let firstNames: Set<String> =
        ["Alex", "Sam", "Jo", "Robin", "Chris", "Morgan", "Casey", "Riley"]
    private static let lastNames: Set<String> =
        ["Archer", "Brook", "Chase", "Dale", "Ellis", "Frost", "Gale", "Hart"]

    /// Every value under a personal-name key must come from the scrubber's
    /// synthetic list.
    ///
    /// This assertion is here because the first version of these tests did not
    /// have it, and its absence let all 100 real customer names in
    /// devices.json through a green suite. The email and phone tests could not
    /// see them: a name is not a pattern, so the only way to check it is to
    /// know what the legitimate values are.
    ///
    /// Keys are matched by SUFFIX, the same way the scrubber matches them, so
    /// `client_first_name` is covered and so is whatever prefix appears next.
    @Test func everyPersonalNameIsSynthetic() throws {
        let personalKey = try NSRegularExpression(
            pattern: #"(^|_)(name|first_?name|last_?name|full_?name|display_?name)$"#,
            options: .caseInsensitive)

        // Keys ending in `name` that name a THING. Mirrors
        // NON_PERSONAL_NAME_KEYS in scripts/scrub-fixture.mjs - if you add one
        // there, add it here, or this test starts failing on catalogue data.
        let nonPersonalKey = try NSRegularExpression(
            pattern: #"(^|_)(device_name|model_name|brand_name|product_name|location_name|company_name|workflow_name|type_name|status_name|group_name|category_name|service_name|repair_name|item_name|file_name|template_name|tag_name)$"#,
            options: .caseInsensitive)

        // A bare `name` is also used for catalogue data the decode tests need
        // unchanged - locations, device types, workflow labels. Those live
        // under one of these parents and are not personal.
        let catalogueParents: Set<String> = [
            "location", "locations", "company_locations", "device_type", "device_types",
            "group", "groups", "ticket_type", "ticket_types", "status", "statuses",
            "payment_status", "payment_statuses", "sub_location", "data", "devices",
        ]

        func check(_ node: Any, key: String, parent: String, file: String) {
            if let a = node as? [Any] { a.forEach { check($0, key: key, parent: parent, file: file) } }
            else if let d = node as? [String: Any] {
                for (k, v) in d { check(v, key: k, parent: key, file: file) }
            } else if let s = node as? String {
                let r = NSRange(key.startIndex..., in: key)
                guard nonPersonalKey.firstMatch(in: key, range: r) == nil else { return }
                guard personalKey.firstMatch(in: key, range: r) != nil else { return }
                let isBare = key.lowercased() == "name" || key.lowercased().hasSuffix("display_name")
                guard !(isBare && catalogueParents.contains(parent.lowercased())) else { return }

                let words = s.split(whereSeparator: { $0 == " " }).map(String.init)
                for w in words {
                    #expect(Self.firstNames.contains(w) || Self.lastNames.contains(w),
                            "\(file).json leaks a real name under '\(key)': \(s)")
                }
            }
        }

        for name in Fixtures.all {
            let json = try JSONSerialization.jsonObject(with: Fixtures.data(name))
            check(json, key: "$", parent: "$", file: name)
        }
    }
}
