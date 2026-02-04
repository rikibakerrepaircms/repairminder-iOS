# Stage 01: Remove Model Core Data Extensions

## Objective

Remove `import CoreData` statements and Core Data conversion extensions from all model files, making models API-only.

## Dependencies

**Requires:** None - this is the first stage

## Complexity

**Medium** - Multiple files to modify with similar changes

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder/Core/Models/Order.swift` | Remove `import CoreData`, remove `// MARK: - Core Data Conversion` extension |
| `Repair Minder/Core/Models/Device.swift` | Remove `import CoreData`, remove `// MARK: - Core Data Conversion` extension |
| `Repair Minder/Core/Models/Client.swift` | Remove `import CoreData`, remove `// MARK: - Core Data Conversion` extension |
| `Repair Minder/Core/Models/Ticket.swift` | Remove `import CoreData`, remove `// MARK: - Core Data Conversion` extension |
| `Repair Minder/Core/Models/TicketMessage.swift` | Remove `import CoreData`, remove `// MARK: - Core Data Conversion` extension |

## Files to Create

None

## Implementation Details

### Pattern for Each Model File

1. **Remove import statement:**
```swift
// DELETE THIS LINE:
import CoreData
```

2. **Remove Core Data conversion extension** - typically at the end of the file:
```swift
// DELETE THIS ENTIRE EXTENSION:
// MARK: - Core Data Conversion
extension ModelName {
    @MainActor
    init(from entity: CDEntityName) {
        // ... initialization from Core Data entity
    }

    @MainActor
    func toEntity(in context: NSManagedObjectContext) -> CDEntityName {
        // ... conversion to Core Data entity
    }
}
```

### Order.swift Specifics
[Ref: Repair Minder/Core/Models/Order.swift]

Remove lines containing:
- `import CoreData`
- The entire `// MARK: - Core Data Conversion` extension (approximately lines 241-284)

### Device.swift Specifics
[Ref: Repair Minder/Core/Models/Device.swift]

Remove lines containing:
- `import CoreData`
- The entire `// MARK: - Core Data Conversion` extension (approximately lines 264-316)

### Client.swift Specifics
[Ref: Repair Minder/Core/Models/Client.swift]

Remove lines containing:
- `import CoreData`
- The entire `// MARK: - Core Data Conversion` extension
- Any `CDClient` extension if present

### Ticket.swift Specifics
[Ref: Repair Minder/Core/Models/Ticket.swift]

Remove lines containing:
- `import CoreData`
- The entire `// MARK: - Core Data Conversion` extension (approximately lines 200-210)

### TicketMessage.swift Specifics
[Ref: Repair Minder/Core/Models/TicketMessage.swift]

Remove lines containing:
- `import CoreData`
- The entire `// MARK: - Core Data Conversion` extension

## Database Changes

None

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Build succeeds | Run `xcodebuild build` | Build completes without errors |
| Order model compiles | Import Order in any file | No compilation errors |
| Device model compiles | Import Device in any file | No compilation errors |
| Client model compiles | Import Client in any file | No compilation errors |
| Ticket model compiles | Import Ticket in any file | No compilation errors |

## Acceptance Checklist

- [ ] `import CoreData` removed from Order.swift
- [ ] Core Data extension removed from Order.swift
- [ ] `import CoreData` removed from Device.swift
- [ ] Core Data extension removed from Device.swift
- [ ] `import CoreData` removed from Client.swift
- [ ] Core Data extension removed from Client.swift
- [ ] `import CoreData` removed from Ticket.swift
- [ ] Core Data extension removed from Ticket.swift
- [ ] `import CoreData` removed from TicketMessage.swift
- [ ] Core Data extension removed from TicketMessage.swift
- [ ] Project builds successfully (may have errors in other files - expected)

## Deployment

```bash
# Build to verify changes
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 16' build 2>&1 | head -100

# Note: Build may fail due to references in other files - this is expected
# Those will be fixed in subsequent stages
```

## Handoff Notes

After this stage:
- Models no longer have Core Data dependencies
- Build will likely fail because SyncEngine and Repositories still reference Core Data types
- [See: Stage 02] will remove ViewModel references to SyncEngine
- [See: Stage 05] will delete the Core Data infrastructure files
