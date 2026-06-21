import SwiftUI

struct StatusPill: View {
    let status: TestStatus

    private var backgroundColor: Color {
        switch status {
        case .pass:    return .green
        case .fail:    return .red
        case .skip:    return Color(.systemGray3)
        case .error:   return .orange
        case .partial: return .orange
        }
    }

    private var statusText: String {
        status.rawValue.capitalized
    }

    var body: some View {
        Text(statusText)
            .font(.caption.weight(.semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule().fill(backgroundColor))
    }
}

#Preview {
    VStack(spacing: 12) {
        StatusPill(status: .pass)
        StatusPill(status: .fail)
        StatusPill(status: .skip)
        StatusPill(status: .error)
        StatusPill(status: .partial)
    }
    .padding()
}
