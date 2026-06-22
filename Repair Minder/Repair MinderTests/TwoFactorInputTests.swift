import Testing
@testable import Repair_Minder

struct TwoFactorInputTests {
    @Test func normalizesToAlnumUppercaseMax8() {
        #expect(TwoFactorView.normalizeCode("ab12-cd34xx") == "AB12CD34")
    }
    @Test func sixDigitsSubmittable() {
        #expect(TwoFactorView.isSubmittable("123456"))
    }
    @Test func eightAlnumSubmittable() {
        #expect(TwoFactorView.isSubmittable("A1B2C3D4"))
    }
    @Test func sixLettersNotSubmittable() {
        #expect(!TwoFactorView.isSubmittable("ABCDEF"))
    }
    @Test func eightCharRecoveryCodeIsSubmittable() {
        #expect(TwoFactorView.isSubmittable("ABCD1234"))
        #expect(TwoFactorView.isSubmittable("123456"))
        #expect(!TwoFactorView.isSubmittable("1234"))
    }
}
