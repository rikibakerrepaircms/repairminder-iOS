# Stage 05: Delete Core Data Files

## Objective

Delete all Core Data infrastructure files including SyncEngine, CoreDataStack, Repositories, and the data model.

## Dependencies

**Requires:** Stage 04 complete (all sync UI components removed)

## Complexity

**Low** - Straightforward file deletion, no code changes

## Files to Delete

| File/Directory | Purpose (for reference) |
|----------------|------------------------|
| `Core/Storage/SyncEngine.swift` | Sync orchestration |
| `Core/Storage/CoreDataStack.swift` | Core Data initialization |
| `Core/Storage/PersistenceController.swift` | Preview/testing helpers |
| `Core/Storage/Repositories/OrderRepository.swift` | Order CRUD with Core Data |
| `Core/Storage/Repositories/DeviceRepository.swift` | Device CRUD with Core Data |
| `Core/Storage/Repositories/ClientRepository.swift` | Client CRUD with Core Data |
| `Core/Storage/Repositories/TicketRepository.swift` | Ticket CRUD with Core Data |
| `Core/Models/SyncMetadata.swift` | Sync tracking model |
| `Resources/RepairMinder.xcdatamodeld/` | Core Data model (entire directory) |

## Files to Modify

None - files are deleted only

## Implementation Details

### Step 1: Verify No References Remain

Before deleting, verify no files still reference these:
```bash
# Search for SyncEngine references
grep -r "SyncEngine" --include="*.swift" .

# Search for CoreDataStack references
grep -r "CoreDataStack" --include="*.swift" .

# Search for Repository references
grep -r "OrderRepository\|DeviceRepository\|ClientRepository\|TicketRepository" --include="*.swift" .

# Search for CD entity references
grep -r "CDOrder\|CDDevice\|CDClient\|CDTicket\|CDTicketMessage" --include="*.swift" .
```

If any references found, they must be removed before proceeding.

### Step 2: Delete Files

```bash
BASE="/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder"

# Delete SyncEngine
rm "$BASE/Core/Storage/SyncEngine.swift"

# Delete CoreDataStack
rm "$BASE/Core/Storage/CoreDataStack.swift"

# Delete PersistenceController (if exists)
rm -f "$BASE/Core/Storage/PersistenceController.swift"

# Delete Repositories directory
rm -rf "$BASE/Core/Storage/Repositories/"

# Delete SyncMetadata model
rm -f "$BASE/Core/Models/SyncMetadata.swift"

# Delete Core Data model (entire directory)
rm -rf "$BASE/Resources/RepairMinder.xcdatamodeld/"
```

### Step 3: Remove Empty Directories

```bash
# Remove Repositories directory if empty
rmdir "$BASE/Core/Storage/Repositories" 2>/dev/null || true

# Check if Storage directory is empty and can be removed
# (likely not, as other files may exist)
ls "$BASE/Core/Storage/"
```

### Files Removed Summary

| Category | Files |
|----------|-------|
| **Sync Infrastructure** | SyncEngine.swift, CoreDataStack.swift, PersistenceController.swift |
| **Repositories** | OrderRepository.swift, DeviceRepository.swift, ClientRepository.swift, TicketRepository.swift |
| **Models** | SyncMetadata.swift |
| **Data Model** | RepairMinder.xcdatamodeld (entire directory) |

**Total: 9 files + 1 directory**

## Database Changes

- `RepairMinder.xcdatamodeld` is deleted
- This removes all Core Data entity definitions (CDOrder, CDDevice, CDClient, CDTicket, CDTicketMessage, CDSyncMetadata)
- Any existing Core Data store on user devices will be orphaned but harmless

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Files deleted | `ls` on paths | Files no longer exist |
| No dangling references | `grep` search | No results for deleted types |
| Build succeeds | `xcodebuild build` | Build completes (may fail due to project refs) |

## Acceptance Checklist

- [ ] SyncEngine.swift deleted
- [ ] CoreDataStack.swift deleted
- [ ] PersistenceController.swift deleted (if existed)
- [ ] OrderRepository.swift deleted
- [ ] DeviceRepository.swift deleted
- [ ] ClientRepository.swift deleted
- [ ] TicketRepository.swift deleted
- [ ] SyncMetadata.swift deleted
- [ ] RepairMinder.xcdatamodeld directory deleted
- [ ] No grep matches for SyncEngine, CoreDataStack, CDOrder, etc.
- [ ] Project builds (or only fails due to Xcode project references)

## Deployment

```bash
# Execute deletion
BASE="/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder"

rm -f "$BASE/Core/Storage/SyncEngine.swift"
rm -f "$BASE/Core/Storage/CoreDataStack.swift"
rm -f "$BASE/Core/Storage/PersistenceController.swift"
rm -rf "$BASE/Core/Storage/Repositories/"
rm -f "$BASE/Core/Models/SyncMetadata.swift"
rm -rf "$BASE/Resources/RepairMinder.xcdatamodeld/"

# Verify deletion
echo "Checking for remaining files..."
ls "$BASE/Core/Storage/SyncEngine.swift" 2>&1
ls "$BASE/Core/Storage/CoreDataStack.swift" 2>&1
ls "$BASE/Resources/RepairMinder.xcdatamodeld/" 2>&1

# Should all report "No such file or directory"
```

## Handoff Notes

After this stage:
- All Core Data infrastructure code is deleted
- Xcode project still has references to deleted files (will cause build errors)
- [See: Stage 06] will update Xcode project to remove file references
- App will not build until Stage 06 is complete

**Important:** The Xcode project file (`.pbxproj`) still contains references to these deleted files. Stage 06 must be completed immediately after this stage.
