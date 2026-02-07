//
//  AnimatedSplitView.swift
//  Repair Minder
//
//  Created on 07/02/2026.
//

import SwiftUI

/// A custom split view that starts full-width and animates to sidebar + detail when a selection is made.
/// Used on iPad to provide a smooth transition from a full-page list to a sidebar/detail layout.
struct AnimatedSplitView<Sidebar: View, Detail: View>: View {
    let showDetail: Bool
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                sidebar()
                    .frame(width: showDetail ? sidebarWidth(for: geo.size.width) : geo.size.width)
                    .clipped()

                if showDetail {
                    Divider()
                    detail()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: showDetail)
        }
    }

    private func sidebarWidth(for totalWidth: CGFloat) -> CGFloat {
        min(380, totalWidth * 0.38)
    }
}
