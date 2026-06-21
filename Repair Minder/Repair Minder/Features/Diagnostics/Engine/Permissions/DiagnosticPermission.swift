// Features/Diagnostics/Engine/Permissions/DiagnosticPermission.swift
import Foundation

/// Permissions a diagnostic test needs, requested up front at Start so the tech isn't
/// interrupted by system prompts mid-flow. NFC and Face ID are deliberately excluded — they
/// are use-time prompts that cannot be pre-granted, so they keep prompting inside their tests.
enum DiagnosticPermission: CaseIterable, Sendable {
    case camera, microphone, location, bluetooth
}

/// Deduped union of the permissions required by a set of tests. Pure — unit-tested without prompts.
func requiredPermissionsUnion(for tests: [DiagnosticTest]) -> Set<DiagnosticPermission> {
    tests.reduce(into: Set<DiagnosticPermission>()) { acc, t in acc.formUnion(t.requiredPermissions) }
}
