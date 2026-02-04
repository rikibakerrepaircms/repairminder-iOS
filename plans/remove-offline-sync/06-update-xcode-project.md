# Stage 06: Update Xcode Project

## Objective

Remove file references from Xcode project for deleted files and verify clean build.

## Dependencies

**Requires:** Stage 05 complete (Core Data files deleted)

## Complexity

**Low** - Project file cleanup and verification

## Files to Modify

| File | Changes |
|------|---------|
| `Repair Minder.xcodeproj/project.pbxproj` | Remove references to deleted files |

## Files to Create

None

## Implementation Details

### Option A: Use Xcode (Recommended)

1. Open `Repair Minder.xcodeproj` in Xcode
2. In Project Navigator, find files shown in red (missing files)
3. For each red file, right-click → Delete → "Remove Reference"
4. Files to remove references for:
   - `SyncEngine.swift`
   - `CoreDataStack.swift`
   - `PersistenceController.swift`
   - `OrderRepository.swift`
   - `DeviceRepository.swift`
   - `ClientRepository.swift`
   - `TicketRepository.swift`
   - `SyncMetadata.swift`
   - `RepairMinder.xcdatamodeld`
   - `SyncStatusBanner.swift`
   - `SyncStatusRow.swift`

5. Build the project (Cmd+B) to verify

### Option B: Manual Project File Editing

**Warning:** Manual editing of `.pbxproj` is error-prone. Use with caution.

1. Open `project.pbxproj` in a text editor
2. Search for and remove all lines containing:
   - `SyncEngine.swift`
   - `CoreDataStack.swift`
   - `PersistenceController.swift`
   - `OrderRepository.swift`
   - `DeviceRepository.swift`
   - `ClientRepository.swift`
   - `TicketRepository.swift`
   - `SyncMetadata.swift`
   - `RepairMinder.xcdatamodeld`
   - `SyncStatusBanner.swift`
   - `SyncStatusRow.swift`

3. Each file typically has 3-4 references:
   - `PBXBuildFile` section (for compilation)
   - `PBXFileReference` section (file definition)
   - `PBXGroup` section (folder structure)
   - `PBXSourcesBuildPhase` section (build phase)

### Option C: Using PlistBuddy/Ruby (Advanced)

```bash
# Use xcodeproj gem if available
# This is a safer alternative to manual editing

gem install xcodeproj

ruby <<'RUBY'
require 'xcodeproj'

project_path = "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj"
project = Xcodeproj::Project.open(project_path)

files_to_remove = [
  'SyncEngine.swift',
  'CoreDataStack.swift',
  'PersistenceController.swift',
  'OrderRepository.swift',
  'DeviceRepository.swift',
  'ClientRepository.swift',
  'TicketRepository.swift',
  'SyncMetadata.swift',
  'SyncStatusBanner.swift',
  'SyncStatusRow.swift'
]

project.files.each do |file|
  if files_to_remove.any? { |name| file.path&.include?(name) }
    puts "Removing: #{file.path}"
    file.remove_from_project
  end
end

# Remove xcdatamodeld
project.files.each do |file|
  if file.path&.include?('RepairMinder.xcdatamodeld')
    puts "Removing: #{file.path}"
    file.remove_from_project
  end
end

project.save
puts "Project saved successfully"
RUBY
```

### Verification Steps

After removing references:

```bash
# Clean build folder
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"
xcodebuild clean -scheme "Repair Minder"

# Build
xcodebuild -scheme "Repair Minder" -destination 'platform=iOS Simulator,name=iPhone 16' build

# If build succeeds, the project is clean
```

### Common Build Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| "No such module 'CoreData'" | CoreData still imported | Remove remaining `import CoreData` lines |
| "Cannot find type 'CDOrder'" | Entity reference remains | Search and remove any CD* references |
| "Cannot find 'SyncEngine'" | Reference not removed | Check for remaining SyncEngine usage |
| "File not found" | Project reference not removed | Use Xcode to remove red file references |

## Database Changes

None

## Test Cases

| Test | Input | Expected Output |
|------|-------|-----------------|
| Project opens | Open in Xcode | No red (missing) files in navigator |
| Clean build | Cmd+Shift+K, then Cmd+B | Build succeeds |
| App launches | Cmd+R | App launches in simulator |
| Dashboard loads | Navigate to Dashboard | Stats and orders display |
| All tabs work | Tap each tab | No crashes, data loads |

## Acceptance Checklist

- [ ] No red (missing) files in Xcode project navigator
- [ ] No references to deleted files in project.pbxproj
- [ ] `xcodebuild clean` succeeds
- [ ] `xcodebuild build` succeeds with no errors
- [ ] App launches successfully in simulator
- [ ] Login flow works
- [ ] Dashboard loads data
- [ ] Orders list loads data
- [ ] Clients list loads data
- [ ] Settings view displays correctly

## Deployment

```bash
# Final verification build
cd "/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder"

# Clean
xcodebuild clean -scheme "Repair Minder" -quiet

# Build for simulator
xcodebuild -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  build \
  2>&1 | tail -20

# If build succeeds, run in simulator
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcodebuild -scheme "Repair Minder" \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  install \
  2>&1 | tail -10

# Launch
xcrun simctl launch "iPhone 16" com.mendmyi.repairminder
```

## Handoff Notes

**This is the final stage.** After completion:

- All Core Data and sync infrastructure has been removed
- App fetches all data directly from API
- No offline storage capability remains
- App binary size should be reduced

### Post-Implementation Verification

1. **Functional Testing:**
   - Login with test credentials
   - Verify Dashboard loads stats
   - Verify Orders list populates
   - Verify Clients list populates
   - Verify Devices list populates (if applicable)
   - Verify Settings displays without Data section
   - Verify logout works

2. **Regression Testing:**
   - Pull-to-refresh on all lists
   - Navigation between tabs
   - Detail view loading
   - Push notification handling (navigation only)

3. **Performance Testing:**
   - App launch time (should be similar or faster)
   - Initial data load time
   - Tab switching responsiveness

### Cleanup Suggestions

Consider removing these if no longer needed:
- `NetworkMonitor.swift` - May still be useful for showing offline state
- Empty `Repositories/` directory
- Any orphaned test files
