// Features/Diagnostics/Transport/DiagnosticsResumeStore.swift
import Foundation

/// Persists the identity of a diagnostics session currently in progress on the server, so a run
/// mid-progress survives the app being closed and reopened. Mirrors `DiagnosticsShopPairing`'s
/// UserDefaults approach — the same non-sensitive rationale applies: a session token only lets you
/// post further results to a session the server already scoped to a company (or the anonymous
/// sentinel), it doesn't grant any new access.
///
/// Written whenever `DiagnosticRunner` opens (or reuses) a live server session; read by the Start
/// screen to offer a "continue where you left off" prompt after an app relaunch; cleared once the
/// session is genuinely finished (submitted) or the operator explicitly starts a new run.
enum DiagnosticsResumeStore {
    private static let sessionIdKey = "diagnostics.resume.sessionId"
    private static let tokenKey = "diagnostics.resume.token"
    private static let reportIDKey = "diagnostics.resume.reportID"
    private static var store: UserDefaults { .standard }

    static func save(sessionId: String, token: String, reportID: String?) {
        guard !sessionId.isEmpty, !token.isEmpty else { return }
        store.set(sessionId, forKey: sessionIdKey)
        store.set(token, forKey: tokenKey)
        if let reportID, !reportID.isEmpty {
            store.set(reportID, forKey: reportIDKey)
        } else {
            store.removeObject(forKey: reportIDKey)
        }
    }

    static func load() -> (sessionId: String, token: String, reportID: String?)? {
        guard let sessionId = store.string(forKey: sessionIdKey), !sessionId.isEmpty,
              let token = store.string(forKey: tokenKey), !token.isEmpty else { return nil }
        let reportID = store.string(forKey: reportIDKey)
        return (sessionId, token, reportID)
    }

    static func clear() {
        store.removeObject(forKey: sessionIdKey)
        store.removeObject(forKey: tokenKey)
        store.removeObject(forKey: reportIDKey)
    }
}
