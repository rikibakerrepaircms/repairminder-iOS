//
//  AiReadiness.swift
//  Repair Minder
//
//  Created on 02/06/2026.
//

import Foundation

// MARK: - AI Readiness

/// Per-feature readiness for AI, returned by `GET /api/company/ai-readiness`.
///
/// A company brings its own LLM provider API key (managed on the web dashboard,
/// Settings → Provider Keys). A feature is `ready` when it is enabled AND the
/// company has a usable key for its provider. No secrets are returned.
///
/// The iOS app only acts on `tickets` today, but all three features are modelled
/// to mirror the web and stay future-proof.
struct AiReadiness: Decodable, Sendable, Equatable {
    let buybackListing: FeatureReadiness
    let buybackImages: FeatureReadiness
    let tickets: FeatureReadiness
}

/// Readiness for a single AI feature.
struct FeatureReadiness: Decodable, Sendable, Equatable {
    /// True when the feature is enabled and a usable provider key exists.
    let ready: Bool
    /// The configured provider name (e.g. "deepseek", "gemini"). Never a secret.
    let provider: String
}
