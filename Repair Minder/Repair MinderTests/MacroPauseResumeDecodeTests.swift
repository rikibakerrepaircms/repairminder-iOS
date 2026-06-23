import Testing
import Foundation
@testable import Repair_Minder

struct MacroPauseResumeDecodeTests {
    private func decoder() -> JSONDecoder { let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d }

    @Test func pauseDecodesFromDataPayloadWithoutSuccess() throws {
        // This is the `data` sub-object the API returns (request<T> unwraps `data`)
        let json = #"{"pending_stages_count":2,"message":"Workflow paused successfully"}"#.data(using: .utf8)!
        let r = try decoder().decode(PauseExecutionResponse.self, from: json)
        #expect(r.pendingStagesCount == 2)
        #expect(r.message == "Workflow paused successfully")
    }

    @Test func resumeDecodesFromDataPayloadWithoutSuccess() throws {
        let json = #"{"message":"Workflow resumed with immediate scheduling"}"#.data(using: .utf8)!
        let r = try decoder().decode(ResumeExecutionResponse.self, from: json)
        #expect(r.message == "Workflow resumed with immediate scheduling")
    }

    @Test func pauseDecodesRealPayloadWithRawExecutionRow() throws {
        let json = #"{"execution":{"id":"e1","macro_id":"m1","ticket_id":"t1","status":"paused","created_at":"2026-06-23 10:00:00"},"pending_stages_count":2,"message":"Workflow paused successfully"}"#.data(using: .utf8)!
        let r = try decoder().decode(PauseExecutionResponse.self, from: json)
        #expect(r.pendingStagesCount == 2)
    }
    @Test func resumeDecodesRealPayloadWithRawExecutionRow() throws {
        let json = #"{"execution":{"id":"e1","macro_id":"m1","ticket_id":"t1","status":"active","created_at":"2026-06-23 10:00:00"},"message":"Workflow resumed with immediate scheduling"}"#.data(using: .utf8)!
        let r = try decoder().decode(ResumeExecutionResponse.self, from: json)
        #expect(r.message == "Workflow resumed with immediate scheduling")
    }
}
