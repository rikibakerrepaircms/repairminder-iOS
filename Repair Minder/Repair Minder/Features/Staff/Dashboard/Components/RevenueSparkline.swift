//
//  RevenueSparkline.swift
//  Repair Minder
//
//  Created on 03/07/2026.
//

import SwiftUI

/// Minimal inline sparkline for a small revenue series (oldest -> newest).
struct RevenueSparkline: View {
    let totals: [Double]

    var body: some View {
        if totals.count >= 2 {
            GeometryReader { geo in
                let minV = totals.min() ?? 0
                let maxV = totals.max() ?? 1
                let range = (maxV - minV) == 0 ? 1 : (maxV - minV)
                let rising = (totals.last ?? 0) >= (totals.first ?? 0)
                Path { p in
                    for (i, v) in totals.enumerated() {
                        let x = geo.size.width * CGFloat(i) / CGFloat(totals.count - 1)
                        let y = geo.size.height * (1 - CGFloat((v - minV) / range))
                        if i == 0 { p.move(to: CGPoint(x: x, y: y)) }
                        else { p.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(rising ? Color.green : Color.red, lineWidth: 2)
            }
            .frame(height: 28)
        }
    }
}
