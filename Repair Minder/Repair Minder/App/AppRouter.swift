//
//  AppRouter.swift
//  Repair Minder
//
//  Created by Claude on 03/02/2026.
//

import SwiftUI

enum AppRoute: Hashable, Sendable {
    case login
    case dashboard
    case orders
    case orderDetail(id: String)
    case devices
    case deviceDetail(id: String)
    case clients
    case clientDetail(id: String)
    case scanner
    case settings
    case enquiries
    case enquiryDetail(id: String)
}

@MainActor
@Observable
final class AppRouter {
    var path = NavigationPath()
    var selectedTab: Tab = .dashboard

    enum Tab: Int, CaseIterable, Sendable {
        case dashboard
        case orders
        case scanner
        case clients
        case settings

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .orders: return "Orders"
            case .scanner: return "Scan"
            case .clients: return "Clients"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .orders: return "doc.text.fill"
            case .scanner: return "qrcode.viewfinder"
            case .clients: return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
