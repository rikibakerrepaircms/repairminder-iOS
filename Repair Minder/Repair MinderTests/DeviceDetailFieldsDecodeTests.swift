//
//  DeviceDetailFieldsDecodeTests.swift
//  Repair MinderTests
//

import Testing
import Foundation
@testable import Repair_Minder

struct DeviceDetailFieldsDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func subLocationOptionDecodes() throws {
        let v = try decoder().decode(SubLocationOption.self, from: #"{"id":"s1","name":"Shelf A"}"#.data(using: .utf8)!)
        #expect(v.id == "s1")
        #expect(v.name == "Shelf A")
    }

    @Test func engineerOptionDecodes() throws {
        let v = try decoder().decode(EngineerFilterInfo.self, from: #"{"id":"e1","name":"Sam Tech"}"#.data(using: .utf8)!)
        #expect(v.name == "Sam Tech")
    }
}
