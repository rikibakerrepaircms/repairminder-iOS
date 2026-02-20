//
//  CollapsibleFAB.swift
//  Repair Minder
//

import SwiftUI

// MARK: - FAB State

@Observable
final class FABState {
    static let shared = FABState()

    var isHidden: Bool

    private init() {
        self.isHidden = UserDefaults.standard.bool(forKey: "fabHidden")
    }

    func hide() {
        guard !isHidden else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            isHidden = true
        }
        UserDefaults.standard.set(true, forKey: "fabHidden")
    }

    func show() {
        guard isHidden else { return }
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            isHidden = false
        }
        UserDefaults.standard.set(false, forKey: "fabHidden")
    }
}

// MARK: - Scroll Detection

extension View {
    /// Attach to any ScrollView or List to hide the booking FAB on downward scroll.
    @ViewBuilder
    func hidesBookingFABOnScroll() -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self) { geo in
                geo.contentOffset.y
            } action: { old, new in
                if new > old + 10 && new > 20 {
                    FABState.shared.hide()
                }
            }
        } else {
            self
        }
    }
}
