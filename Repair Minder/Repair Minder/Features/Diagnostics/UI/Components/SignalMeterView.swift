import SwiftUI

struct SignalMeterView: View {
    let value: Double
    let threshold: Double
    var label: String = ""

    private var fraction: Double {
        guard threshold > 0 else { return 0 }
        return min(value / threshold, 1.0)
    }

    private var isAboveThreshold: Bool {
        value >= threshold && threshold > 0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isAboveThreshold ? Color.accentColor : Color(.systemGray3))
                        .frame(width: geometry.size.width * fraction, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: fraction)
                }
            }
            .frame(height: 8)
            .accessibilityIdentifier("signal-meter")
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        SignalMeterView(value: 0.3, threshold: 1.0, label: "Below threshold")
        SignalMeterView(value: 1.0, threshold: 1.0, label: "At threshold")
        SignalMeterView(value: 1.5, threshold: 1.0, label: "Above threshold")
        SignalMeterView(value: 0.0, threshold: 0.0, label: "Zero threshold guard")
    }
    .padding()
}
