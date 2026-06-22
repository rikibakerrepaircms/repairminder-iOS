import Testing
@testable import Repair_Minder

@MainActor
struct RegistryPermissionUnionTests {
    // The union over the *supported* battery never declares a permission outside the four the
    // app knows how to pre-grant. (Subset, not equality: camera-requiring tests use AVCaptureDevice
    // availability for isSupported, so on a camera-less simulator .camera drops out of the supported
    // union. Equality would only hold on real hardware — see unionOverFullRegistryIsExactlyTheFour.)
    @Test func unionOverSupportedRegistryIsSubsetOfTheFourPermissions() {
        let union = requiredPermissionsUnion(for: TestRegistry.supportedTests())
        #expect(union.isSubset(of: Set<DiagnosticPermission>([.camera, .microphone, .location, .bluetooth])))
    }

    // Over the *full* registry (capability-independent) the declared union is exactly the four
    // permissions the app pre-grants — the I2 over-declaration regression guard. A re-introduced
    // stray permission (or a 5th case) would break this regardless of device hardware.
    @Test func unionOverFullRegistryIsExactlyTheFourPermissions() {
        let union = requiredPermissionsUnion(for: TestRegistry.allTests())
        #expect(union == Set<DiagnosticPermission>([.camera, .microphone, .location, .bluetooth]))
    }

    // I2 regression: Magnetic must NOT contribute .location after the fix.
    @Test func magneticTestDoesNotRequireLocation() {
        let magnetic = TestRegistry.allTests().first { $0.id == "magnetic" }
        #expect(magnetic != nil)
        #expect(!(magnetic?.requiredPermissions.contains(.location) ?? true))
    }

    // Location is still in the overall union via GPS (proves we didn't drop it wholesale).
    @Test func gpsStillRequiresLocation() {
        let gps = TestRegistry.allTests().first { $0.id == "gps" }
        #expect(gps?.requiredPermissions.contains(.location) == true)
    }
}
