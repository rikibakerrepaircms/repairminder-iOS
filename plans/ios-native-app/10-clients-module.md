# Stage 10: Clients Module

## Objective

Build client list and detail views with order history and contact actions.

---

## Dependencies

**Requires:** [See: Stage 07] complete - Orders module exists for order history

---

## Complexity

**Low** - Standard list/detail pattern

---

## Files to Create

| File | Purpose |
|------|---------|
| `Features/Clients/ClientListView.swift` | Searchable client list |
| `Features/Clients/ClientListViewModel.swift` | List logic |
| `Features/Clients/ClientDetailView.swift` | Client profile & orders |
| `Features/Clients/ClientDetailViewModel.swift` | Detail logic |
| `Features/Clients/Components/ClientAvatar.swift` | Avatar with initials |
| `Features/Clients/Components/ContactActionsView.swift` | Call/email buttons |

---

## Implementation Details

### Client List View

```swift
struct ClientListView: View {
    @StateObject private var viewModel = ClientListViewModel()
    @EnvironmentObject var router: AppRouter

    var body: some View {
        NavigationStack(path: $router.path) {
            List {
                ForEach(viewModel.clients) { client in
                    ClientListRow(client: client)
                        .onTapGesture {
                            router.navigate(to: .clientDetail(id: client.id))
                        }
                }

                if viewModel.hasMorePages {
                    ProgressView()
                        .onAppear { Task { await viewModel.loadMore() } }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Clients")
            .navigationDestination(for: AppRoute.self) { route in
                if case .clientDetail(let id) = route {
                    ClientDetailView(clientId: id)
                }
            }
            .searchable(text: $viewModel.searchText)
            .refreshable { await viewModel.refresh() }
            .task { await viewModel.loadClients() }
        }
    }
}

struct ClientListRow: View {
    let client: Client

    var body: some View {
        HStack(spacing: 12) {
            ClientAvatar(name: client.displayName, size: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(client.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(client.email)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(client.orderCount) orders")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("£\(NSDecimalNumber(decimal: client.totalSpent).intValue)")
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}
```

### Client Detail View

```swift
struct ClientDetailView: View {
    let clientId: String
    @StateObject private var viewModel: ClientDetailViewModel

    init(clientId: String) {
        self.clientId = clientId
        _viewModel = StateObject(wrappedValue: ClientDetailViewModel(clientId: clientId))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                if let client = viewModel.client {
                    ClientHeader(client: client)
                    ContactActionsView(client: client)
                    ClientStatsCard(client: client)
                }

                // Order History
                OrderHistorySection(orders: viewModel.orders)
            }
            .padding()
        }
        .navigationTitle(viewModel.client?.displayName ?? "Client")
        .task { await viewModel.load() }
    }
}

struct ClientHeader: View {
    let client: Client

    var body: some View {
        VStack(spacing: 12) {
            ClientAvatar(name: client.displayName, size: 80)

            Text(client.displayName)
                .font(.title2)
                .fontWeight(.bold)

            Text(client.email)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            if let phone = client.phone {
                Text(phone)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ContactActionsView: View {
    let client: Client

    var body: some View {
        HStack(spacing: 16) {
            if let phone = client.phone, let url = URL(string: "tel:\(phone)") {
                ContactButton(icon: "phone.fill", title: "Call", url: url)
            }

            if let url = URL(string: "mailto:\(client.email)") {
                ContactButton(icon: "envelope.fill", title: "Email", url: url)
            }

            if let phone = client.phone, let url = URL(string: "sms:\(phone)") {
                ContactButton(icon: "message.fill", title: "Message", url: url)
            }
        }
    }
}

struct ContactButton: View {
    let icon: String
    let title: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct ClientStatsCard: View {
    let client: Client

    var body: some View {
        HStack {
            StatItem(title: "Orders", value: "\(client.orderCount)")
            Divider()
            StatItem(title: "Total Spent", value: "£\(NSDecimalNumber(decimal: client.totalSpent).intValue)")
            Divider()
            StatItem(title: "Since", value: client.createdAt.formatted(as: .medium))
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct StatItem: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
```

### Client Avatar

```swift
struct ClientAvatar: View {
    let name: String
    let size: CGFloat

    var initials: String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return "\(parts[0].first ?? "?")\(parts[1].first ?? "?")"
        }
        return String(name.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.system(size: size * 0.4, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(avatarColor)
            .clipShape(Circle())
    }

    var avatarColor: Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal]
        let index = abs(name.hashValue) % colors.count
        return colors[index]
    }
}
```

---

## Test Cases

| Test | Expected |
|------|----------|
| Client list loads | Shows all clients |
| Search filters | Matches name/email |
| Client detail loads | Shows full profile |
| Call button | Opens phone app |
| Email button | Opens mail app |
| Message button | Opens messages app |
| Order history | Shows client's orders |

---

## Acceptance Checklist

- [ ] Client list displays with search
- [ ] Pagination works
- [ ] Client detail shows all info
- [ ] Contact actions work (tel:, mailto:, sms:)
- [ ] Stats display correctly
- [ ] Order history loads
- [ ] Navigation to order detail works

---

## Handoff Notes

**For Stage 12:**
- Client model can be reused for customer portal
- Avatar component reusable
