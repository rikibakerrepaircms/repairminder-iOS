import Testing
import Foundation
@testable import Repair_Minder

struct AIJobDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func decodesStartResponse() throws {
        let json = #"{"job_id":"j1","status":"running"}"#.data(using: .utf8)!
        let r = try decoder().decode(AIJobStart.self, from: json)
        #expect(r.jobId == "j1")
        #expect(r.status == "running")
    }

    @Test func decodesDoneStatusWithResult() throws {
        let json = #"""
        {"status":"done","result":{"text":"Hi","usage":{"input_tokens":5,"output_tokens":7,"cost":0.01},"model":"claude","provider":"anthropic"}}
        """#.data(using: .utf8)!
        let r = try decoder().decode(AIJobStatus.self, from: json)
        #expect(r.status == "done")
        #expect(r.result?.text == "Hi")
    }

    @Test func decodesIdleStatusNoResult() throws {
        let json = #"{"status":"idle"}"#.data(using: .utf8)!
        let r = try decoder().decode(AIJobStatus.self, from: json)
        #expect(r.status == "idle")
        #expect(r.result == nil)
    }
}
