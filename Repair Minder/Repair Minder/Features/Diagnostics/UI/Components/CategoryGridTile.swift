import SwiftUI

struct CategoryGridTile: View {
    let title: String
    let count: Int
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(selected ? .white : .primary)
                    .lineLimit(2)
                Text("\(count) tests")
                    .font(.subheadline)
                    .foregroundColor(selected ? .white.opacity(0.85) : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(selected ? Color.accentColor : Color(.systemGray6))
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
        CategoryGridTile(title: "Battery", count: 5, selected: true, action: {})
        CategoryGridTile(title: "Display", count: 3, selected: false, action: {})
        CategoryGridTile(title: "Camera", count: 4, selected: false, action: {})
        CategoryGridTile(title: "Connectivity", count: 6, selected: true, action: {})
    }
    .padding()
}
