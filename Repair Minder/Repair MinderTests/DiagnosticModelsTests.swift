// Repair MinderTests/DiagnosticModelsTests.swift
import Testing
import Foundation
@testable import Repair_Minder

struct DiagnosticModelsTests {
    private func encoder() -> JSONEncoder { let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e }
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func sessionResponseDecodesSnakeCase() throws {
        let json = #"{"session_id":"abc","session_token":"tok","expires_at":"2026-06-20T10:00:00Z"}"#.data(using: .utf8)!
        let r = try decoder().decode(DiagnosticSessionResponse.self, from: json)
        #expect(r.sessionId == "abc")
        #expect(r.sessionToken == "tok")
    }

    @Test func createRequestEncodesSnakeCase() throws {
        let req = CreateSessionRequest(shopCode: "123456", platform: "ios", deviceIdentifier: "UDID", deviceDescription: "iPhone 15", imei: "350069708103628", serial: "C7332")
        let data = try encoder().encode(req)
        let s = String(data: data, encoding: .utf8)!
        #expect(s.contains("\"shop_code\":\"123456\""))
        #expect(s.contains("\"device_description\":\"iPhone 15\""))
    }

    @Test func resultPayloadEncodesStatusRawValue() throws {
        let p = DiagnosticResultPayload(sessionId: "s", token: "t", testName: "camera_rear", status: .pass, details: nil)
        let s = String(data: try encoder().encode(p), encoding: .utf8)!
        #expect(s.contains("\"test_name\":\"camera_rear\""))
        #expect(s.contains("\"status\":\"pass\""))
    }

    @Test func createRequestEncodesTotalTestsAndStartedAt() throws {
        let req = CreateSessionRequest(shopCode: "123456", platform: "ios", reportID: "RM-1",
                                       totalTests: 22, startedAt: "2026-07-11T09:00:00Z")
        let s = String(data: try encoder().encode(req), encoding: .utf8)!
        #expect(s.contains("\"total_tests\":22"))
        #expect(s.contains("\"started_at\":\"2026-07-11T09:00:00Z\""))
    }

    @Test func createRequestOmitsTotalTestsAndStartedAtWhenNil() throws {
        // Additive fields default to nil so older callers (transmit()'s batch path) don't need
        // to be updated to keep compiling; JSONEncoder drops nil Optionals by default.
        let req = CreateSessionRequest(shopCode: "123456", platform: "ios", reportID: "RM-1")
        let s = String(data: try encoder().encode(req), encoding: .utf8)!
        #expect(!s.contains("total_tests"))
        #expect(!s.contains("started_at"))
    }
}
