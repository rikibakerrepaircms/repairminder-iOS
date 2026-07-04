//
//  KioskLaunch.swift
//  Repair Minder
//
//  Environment launcher used to trigger the full-screen Kiosk takeover from
//  descendant views (e.g. the More menu). The closure is injected by
//  StaffMainView, which owns the actual `.fullScreenCover` presentation state.
//

import SwiftUI

private struct KioskLaunchKey: EnvironmentKey {
    static let defaultValue: () -> Void = {}
}

extension EnvironmentValues {
    var launchKiosk: () -> Void {
        get { self[KioskLaunchKey.self] }
        set { self[KioskLaunchKey.self] = newValue }
    }
}
