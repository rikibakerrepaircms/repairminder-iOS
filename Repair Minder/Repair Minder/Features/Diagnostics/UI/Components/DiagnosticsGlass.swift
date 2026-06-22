//
//  DiagnosticsGlass.swift
//  Repair Minder
//
//  Created on 22/06/2026.
//

import SwiftUI

// MARK: - iOS 26 Liquid Glass helpers (shared across the Diagnostics feature)
//
// Single availability guard point for the Diagnostics flow. iOS 26+ uses Liquid
// Glass APIs; older OSes fall back to the exact look these screens shipped with
// (.background(...) / .buttonStyle(.borderedProminent)). Route every Diagnostics
// glass site through these — no per-call-site #available.
//
// The guard convention (`if #available(iOS 26, macOS 26, *)`) and the
// `Color.platform*` fallback colours mirror the Board file's helpers
// (Features/Staff/Board/BoardCardView.swift) so the look stays consistent and the
// file compiles on both the iOS and macOS targets.

/// Wraps related glass shapes so they blend/morph as one (e.g. the Pass/Fail/Skip trio).
struct RMGlassEffectContainer<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content

    init(spacing: CGFloat = 12, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        if #available(iOS 26, macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}

extension View {
    /// Card / tile background: regular glass on iOS 26+, flat fill + clip on older.
    @ViewBuilder
    func rmGlassCardBackground(cornerRadius: CGFloat,
                               fallbackFill: Color = .platformBackground) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(fallbackFill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Tinted card / tile background (selection + result tiles). `tint` drives the iOS 26 glass
    /// tint; `fallbackFill` reproduces today's flat colour on older OSes.
    @ViewBuilder
    func rmGlassTintedCard(cornerRadius: CGFloat,
                           tint: Color,
                           fallbackFill: Color) -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular.tint(tint), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            self
                .background(fallbackFill)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    /// Capsule glass (e.g. the Preparing banner): regular glass capsule on iOS 26+,
    /// ultraThinMaterial capsule on older (today's look).
    @ViewBuilder
    func rmGlassCapsule() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.glassEffect(.regular, in: Capsule())
        } else {
            self.background(.ultraThinMaterial, in: Capsule())
        }
    }

    /// Soft scroll-edge effect under the top bar on iOS 26+; no-op below.
    @ViewBuilder
    func rmSoftTopScrollEdge() -> some View {
        if #available(iOS 26, macOS 26, *) {
            self.scrollEdgeEffectStyle(.soft, for: .top)
        } else {
            self
        }
    }
}

// MARK: - Glass buttons

/// Primary call-to-action: `.glassProminent` tinted on iOS 26+, `.borderedProminent` on older.
struct RMGlassProminentButtonStyle: PrimitiveButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, macOS 26, *) {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(.glassProminent)
            .tint(tint)
        } else {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(.borderedProminent)
            .tint(tint)
        }
    }
}

/// Secondary action (e.g. Skip / "Continue anyway"): `.glass` on iOS 26+, `.bordered` on older.
struct RMGlassButtonStyle: PrimitiveButtonStyle {
    var tint: Color = .accentColor

    func makeBody(configuration: Configuration) -> some View {
        if #available(iOS 26, macOS 26, *) {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(.glass)
            .tint(tint)
        } else {
            Button(role: configuration.role, action: configuration.trigger) {
                configuration.label
            }
            .buttonStyle(.bordered)
            .tint(tint)
        }
    }
}

extension PrimitiveButtonStyle where Self == RMGlassProminentButtonStyle {
    static func rmGlassProminent(tint: Color = .accentColor) -> RMGlassProminentButtonStyle {
        RMGlassProminentButtonStyle(tint: tint)
    }
}
extension PrimitiveButtonStyle where Self == RMGlassButtonStyle {
    static func rmGlass(tint: Color = .accentColor) -> RMGlassButtonStyle {
        RMGlassButtonStyle(tint: tint)
    }
}
