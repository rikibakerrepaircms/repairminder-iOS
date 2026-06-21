// Repair MinderTests/DiagnosticPermissionTests.swift
import Testing
@testable import Repair_Minder

@MainActor
struct DiagnosticPermissionTests {
    struct P: DiagnosticTest {
        let id: String
        let name = "P"
        let category: TestCategory = .sensors
        let requiresInteraction = false
        let isSupported = true
        let perms: [DiagnosticPermission]
        var requiredPermissions: [DiagnosticPermission] { perms }
        func run() async -> TestOutcome { TestOutcome(id: id, name: name, status: .pass, details: nil) }
    }

    @Test func unionDedupesAcrossTests() {
        let tests = [
            P(id: "a", perms: [.camera, .microphone]),
            P(id: "b", perms: [.camera, .location]),
            P(id: "c", perms: []),
        ]
        #expect(requiredPermissionsUnion(for: tests) == Set([.camera, .microphone, .location]))
    }

    @Test func unionEmptyWhenNoneRequirePermissions() {
        let tests = [P(id: "a", perms: []), P(id: "b", perms: [])]
        #expect(requiredPermissionsUnion(for: tests).isEmpty)
    }

    @MainActor @Test func permissionUnionOverSupportedRegistryHasNoStrayLocation() {
        let union = Set(TestRegistry.supportedTests().flatMap { $0.requiredPermissions })
        // Magnetic must NOT contribute .location; GPS still legitimately requires it on devices
        // where GPS is supported. Assert no permission outside the known set leaks in.
        #expect(union.isSubset(of: [.camera, .microphone, .location, .bluetooth]))
        // Magnetic test specifically declares nothing.
        #expect(MagneticTest().requiredPermissions.isEmpty)
    }
}
