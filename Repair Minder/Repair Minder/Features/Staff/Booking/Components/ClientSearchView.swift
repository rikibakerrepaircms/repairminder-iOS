//
//  ClientSearchView.swift
//  Repair Minder
//

import SwiftUI

struct ClientSearchView: View {
    @Binding var query: String
    let results: [Client]
    let isSearching: Bool
    let selectedClient: Client?
    let onSearch: (String) -> Void
    let onSelect: (Client) -> Void
    let onClear: () -> Void

    @State private var showResults = false
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Search Existing Customers")
                .font(.subheadline)
                .fontWeight(.medium)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search by name, email, or phone", text: $query)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($isFocused)
                    .onChange(of: query) { _, newValue in
                        showResults = !newValue.isEmpty
                        searchTask?.cancel()
                        searchTask = Task {
                            try? await Task.sleep(for: .milliseconds(300))
                            guard !Task.isCancelled else { return }
                            onSearch(newValue)
                        }
                    }

                if isSearching {
                    ProgressView()
                } else if !query.isEmpty {
                    Button {
                        query = ""
                        showResults = false
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            // Search Results
            if showResults && !results.isEmpty {
                VStack(spacing: 0) {
                    ForEach(results) { client in
                        Button {
                            onSelect(client)
                            query = ""
                            showResults = false
                            isFocused = false
                        } label: {
                            ClientSearchResultRow(client: client)
                        }
                        .buttonStyle(.plain)

                        if client.id != results.last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            }

            // No results message
            if showResults && results.isEmpty && !isSearching && query.count >= 2 {
                Text("No customers found matching \"\(query)\"")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)
            }
        }
    }
}

struct ClientSearchResultRow: View {
    let client: Client

    var body: some View {
        HStack {
            // Avatar
            Circle()
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay {
                    Text(client.initials)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.accentColor)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)

                Text(client.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let phone = client.phone, !phone.isEmpty {
                    Text(phone)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(client.effectiveOrderCount) orders")
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                Text("\(client.effectiveDeviceCount) devices")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}

#Preview {
    VStack {
        ClientSearchView(
            query: .constant("john"),
            results: [],
            isSearching: false,
            selectedClient: nil,
            onSearch: { _ in },
            onSelect: { _ in },
            onClear: {}
        )
    }
    .padding()
}
