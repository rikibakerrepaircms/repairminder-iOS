import Testing
@testable import Repair_Minder

struct DiagnosticsSessionIDTests {
    @Test func acceptsThirtyTwoLowerHex() {
        #expect(DiagnosticsSessionID.isValid("0123456789abcdef0123456789abcdef") == true)
    }
    @Test func rejectsWrongLengthUppercaseDashesAndStub() {
        #expect(DiagnosticsSessionID.isValid("stub") == false)
        #expect(DiagnosticsSessionID.isValid("0123456789ABCDEF0123456789ABCDEF") == false) // uppercase
        #expect(DiagnosticsSessionID.isValid("0123456789abcdef") == false)                  // too short
        #expect(DiagnosticsSessionID.isValid("0123456789abcdef0123456789abcdef0") == false) // too long
        #expect(DiagnosticsSessionID.isValid("0123456789abcdef-123456789abcdef") == false)  // dash
    }
}
