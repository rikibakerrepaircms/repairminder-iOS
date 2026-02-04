# Stage 01: Project Architecture

## Objective

Set up the iOS project folder structure, configure build settings, and establish the foundational architecture for both Staff and Customer app targets.

---

## Dependencies

**Requires:** None (first stage)

---

## Complexity

**Medium** - Structural setup, no complex logic

---

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Repair Minder.xcodeproj/project.pbxproj` | Add folder references, build settings |
| `Repair Minder/Repair Minder/ContentView.swift` | Replace with app shell/router |
| `Repair Minder/Repair Minder/Repair_MinderApp.swift` | Configure app entry point |

---

## Files to Create

| File | Purpose |
|------|---------|
| `Repair Minder/Repair Minder/App/AppState.swift` | Global app state (auth, sync status) |
| `Repair Minder/Repair Minder/App/AppRouter.swift` | Navigation router |
| `Repair Minder/Repair Minder/Core/README.md` | Documentation for Core module |
| `Repair Minder/Repair Minder/Features/README.md` | Documentation for Features module |
| `Repair Minder/Repair Minder/Shared/README.md` | Documentation for Shared module |
| `Repair Minder/Repair Minder/Shared/Extensions/Date+Extensions.swift` | Date formatting utilities |
| `Repair Minder/Repair Minder/Shared/Extensions/String+Extensions.swift` | String utilities |
| `Repair Minder/Repair Minder/Shared/Extensions/View+Extensions.swift` | SwiftUI view modifiers |
| `Repair Minder/Repair Minder/Shared/Components/LoadingView.swift` | Reusable loading indicator |
| `Repair Minder/Repair Minder/Shared/Components/ErrorView.swift` | Reusable error display |
| `Repair Minder/Repair Minder/Shared/Components/EmptyStateView.swift` | Empty state placeholder |
| `Repair Minder/Repair Minder/Core/Config/Environment.swift` | API URLs, feature flags |

---

## Implementation Details

### 1. Create Folder Structure

Create the following folder hierarchy in Xcode:

```
Repair Minder/
├── App/
├── Core/
│   ├── Config/
│   ├── Networking/
│   ├── Storage/
│   └── Models/
├── Features/
│   ├── Auth/
│   ├── Dashboard/
│   ├── Orders/
│   ├── Devices/
│   ├── Clients/
│   ├── Scanner/
│   └── Settings/
├── Shared/
│   ├── Components/
│   ├── Extensions/
│   └── Utilities/
└── Resources/
```

### 2. Environment Configuration

```swift
// Core/Config/Environment.swift
import Foundation

enum AppEnvironment {
    case development
    case staging
    case production

    static var current: AppEnvironment {
        #if DEBUG
        return .development
        #else
        return .production
        #endif
    }

    var apiBaseURL: URL {
        switch self {
        case .development:
            return URL(string: "https://api.repairminder.com")!
        case .staging:
            return URL(string: "https://api-staging.repairminder.com")!
        case .production:
            return URL(string: "https://api.repairminder.com")!
        }
    }

    var appName: String {
        return "Repair Minder"
    }
}
```

### 3. App State Management

```swift
// App/AppState.swift
import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isAuthenticated: Bool = false
    @Published var currentUser: User?
    @Published var isLoading: Bool = true
    @Published var syncStatus: SyncStatus = .idle

    enum SyncStatus {
        case idle
        case syncing
        case error(String)
        case offline
    }

    init() {
        // Check for existing auth token on launch
        checkAuthStatus()
    }

    private func checkAuthStatus() {
        // Will be implemented in Stage 03
        isLoading = false
    }
}
```

### 4. App Router

```swift
// App/AppRouter.swift
import SwiftUI

enum AppRoute: Hashable {
    case login
    case dashboard
    case orders
    case orderDetail(id: String)
    case devices
    case deviceDetail(id: String)
    case clients
    case clientDetail(id: String)
    case scanner
    case settings
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var path = NavigationPath()
    @Published var selectedTab: Tab = .dashboard

    enum Tab: Int, CaseIterable {
        case dashboard
        case orders
        case scanner
        case clients
        case settings

        var title: String {
            switch self {
            case .dashboard: return "Dashboard"
            case .orders: return "Orders"
            case .scanner: return "Scan"
            case .clients: return "Clients"
            case .settings: return "Settings"
            }
        }

        var icon: String {
            switch self {
            case .dashboard: return "chart.bar.fill"
            case .orders: return "doc.text.fill"
            case .scanner: return "qrcode.viewfinder"
            case .clients: return "person.2.fill"
            case .settings: return "gearshape.fill"
            }
        }
    }

    func navigate(to route: AppRoute) {
        path.append(route)
    }

    func pop() {
        if !path.isEmpty {
            path.removeLast()
        }
    }

    func popToRoot() {
        path = NavigationPath()
    }
}
```

### 5. Main App Entry Point

```swift
// Repair_MinderApp.swift
import SwiftUI

@main
struct Repair_MinderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var router = AppRouter()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(router)
        }
    }
}
```

### 6. Content View (App Shell)

```swift
// ContentView.swift
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var router: AppRouter

    var body: some View {
        Group {
            if appState.isLoading {
                LoadingView(message: "Loading...")
            } else if appState.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
    }
}

struct MainTabView: View {
    @EnvironmentObject var router: AppRouter

    var body: some View {
        TabView(selection: $router.selectedTab) {
            ForEach(AppRouter.Tab.allCases, id: \.self) { tab in
                tabContent(for: tab)
                    .tabItem {
                        Label(tab.title, systemImage: tab.icon)
                    }
                    .tag(tab)
            }
        }
    }

    @ViewBuilder
    private func tabContent(for tab: AppRouter.Tab) -> some View {
        switch tab {
        case .dashboard:
            PlaceholderView(title: "Dashboard", message: "Coming in Stage 06")
        case .orders:
            PlaceholderView(title: "Orders", message: "Coming in Stage 07")
        case .scanner:
            PlaceholderView(title: "Scanner", message: "Coming in Stage 09")
        case .clients:
            PlaceholderView(title: "Clients", message: "Coming in Stage 10")
        case .settings:
            PlaceholderView(title: "Settings", message: "Coming in Stage 13")
        }
    }
}

// Temporary placeholder for unimplemented views
struct PlaceholderView: View {
    let title: String
    let message: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "hammer.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.secondary)
                Text(message)
                    .foregroundStyle(.secondary)
            }
            .navigationTitle(title)
        }
    }
}

// Temporary LoginView placeholder
struct LoginView: View {
    var body: some View {
        PlaceholderView(title: "Login", message: "Coming in Stage 03")
    }
}
```

### 7. Shared Components

```swift
// Shared/Components/LoadingView.swift
import SwiftUI

struct LoadingView: View {
    var message: String = "Loading..."

    var body: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    LoadingView()
}
```

```swift
// Shared/Components/ErrorView.swift
import SwiftUI

struct ErrorView: View {
    let error: String
    var retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 50))
                .foregroundStyle(.orange)

            Text("Something went wrong")
                .font(.headline)

            Text(error)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let retryAction {
                Button("Try Again") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    ErrorView(error: "Network connection failed") {
        print("Retry tapped")
    }
}
```

```swift
// Shared/Components/EmptyStateView.swift
import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text(title)
                .font(.headline)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            if let actionTitle, let action {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    EmptyStateView(
        icon: "doc.text",
        title: "No Orders",
        message: "You don't have any orders yet",
        actionTitle: "Create Order"
    ) {
        print("Create tapped")
    }
}
```

### 8. Extensions

```swift
// Shared/Extensions/Date+Extensions.swift
import Foundation

extension Date {
    func formatted(as style: DateFormatter.Style) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = style
        formatter.timeStyle = .none
        return formatter.string(from: self)
    }

    func relativeFormatted() -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: self, relativeTo: Date())
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
}
```

```swift
// Shared/Extensions/String+Extensions.swift
import Foundation

extension String {
    var isValidEmail: Bool {
        let emailRegex = #"^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$"#
        return self.range(of: emailRegex, options: .regularExpression) != nil
    }

    var trimmed: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func truncated(to length: Int, trailing: String = "...") -> String {
        if self.count <= length {
            return self
        }
        return String(self.prefix(length)) + trailing
    }
}
```

```swift
// Shared/Extensions/View+Extensions.swift
import SwiftUI

extension View {
    func cornerRadius(_ radius: CGFloat, corners: UIRectCorner) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }

    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(
            roundedRect: rect,
            byRoundingCorners: corners,
            cornerRadii: CGSize(width: radius, height: radius)
        )
        return Path(path.cgPath)
    }
}
```

---

## Database Changes

None in this stage.

---

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| App launches | Run app | Loading view appears, then Login view |
| Tab bar renders | Authenticate user (mock) | 5 tabs visible with correct icons |
| Navigation works | Tap each tab | Correct placeholder view shown |
| LoadingView displays | Show LoadingView | Spinner and message visible |
| ErrorView displays | Show ErrorView | Error icon, message, retry button visible |
| EmptyStateView displays | Show EmptyStateView | Icon, title, message, action button visible |

---

## Acceptance Checklist

- [ ] Project builds without errors
- [ ] Folder structure created as specified
- [ ] App launches and shows LoadingView briefly
- [ ] App transitions to LoginView (placeholder) when not authenticated
- [ ] AppState is available via @EnvironmentObject
- [ ] AppRouter is available via @EnvironmentObject
- [ ] All shared components render correctly in previews
- [ ] Extensions compile without errors
- [ ] Environment configuration returns correct API URL

---

## Deployment

### Build Commands

```bash
# Build for simulator
xcodebuild -project "Repair Minder.xcodeproj" \
  -scheme "Repair Minder" \
  -destination "platform=iOS Simulator,name=iPhone 16" \
  build

# Or use XcodeBuildMCP
# mcp__XcodeBuildMCP__build_sim
```

### Verification

1. Run app in simulator
2. Verify LoadingView appears briefly
3. Verify LoginView placeholder appears
4. Check Console for any warnings/errors

---

## Handoff Notes

**For Stage 02:**
- `Environment.swift` contains `apiBaseURL` - use this for API client
- `AppState` will need `authToken` property added
- `AppRouter` navigation pattern is established - extend as needed
- Shared components are ready for use in feature views
