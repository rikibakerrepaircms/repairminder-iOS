import SwiftUI

func assetStatusColor(_ status: AssetStatus) -> Color {
    switch status {
    case .inStock:       return .green
    case .allocated:     return .blue
    case .reserved:      return .teal
    case .deployed:      return .purple
    case .used:          return .gray
    case .returned:      return .orange
    case .damaged:       return .red
    case .sold:          return .indigo
    case .pendingReturn: return .yellow
    case .unknown:       return .secondary
    }
}

struct AssetStatusBadge: View {
    let status: AssetStatus
    var body: some View {
        Text(status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(assetStatusColor(status).opacity(0.15))
            .foregroundStyle(assetStatusColor(status))
            .clipShape(Capsule())
    }
}
