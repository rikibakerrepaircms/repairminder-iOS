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

/// Colour mapping for condition grades, matching the web app's `CONDITION_COLORS`
/// (A=green … F=red, with an unrecognised grade falling back to grey).
func conditionGradeColor(_ grade: String) -> Color {
    switch grade.uppercased() {
    case "A": return .green
    case "B": return .blue
    case "C": return .yellow
    case "D": return .orange
    case "F": return .red
    default:  return .secondary
    }
}

/// Small capsule badge for an asset's condition grade (A/B/C/D/F), styled to match
/// `AssetStatusBadge`.
struct ConditionGradeBadge: View {
    let grade: String
    var body: some View {
        Text("Grade \(grade)")
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(conditionGradeColor(grade).opacity(0.15))
            .foregroundStyle(conditionGradeColor(grade))
            .clipShape(Capsule())
    }
}
