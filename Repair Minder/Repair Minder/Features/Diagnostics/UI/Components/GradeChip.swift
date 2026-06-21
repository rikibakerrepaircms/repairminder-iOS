import SwiftUI

struct GradeChip: View {
    let grade: DiagnosticGrade

    private var backgroundColor: Color {
        switch grade {
        case .bad:       return .red
        case .good:      return Color.orange
        case .excellent: return .green
        }
    }

    private var gradeText: String {
        switch grade {
        case .bad:       return "Bad"
        case .good:      return "Good"
        case .excellent: return "Excellent"
        }
    }

    var body: some View {
        Text(gradeText)
            .font(.headline.weight(.bold))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(Capsule().fill(backgroundColor))
    }
}

#Preview {
    VStack(spacing: 12) {
        GradeChip(grade: .bad)
        GradeChip(grade: .good)
        GradeChip(grade: .excellent)
    }
    .padding()
}
