# Stage 15: Integration Testing

## Objective

Perform end-to-end testing of both apps to verify all API integrations work correctly.

## Dependencies

- **Requires**: All previous stages complete (01-14)

## Complexity

**Medium** - Systematic testing across all features

## Files to Modify

None (testing stage)

## Files to Create

| File | Purpose |
|------|---------|
| `plans/ios-api-alignment/test-results.md` | Document test results |

## Testing Environments

### Required Setup

1. **Backend running** - Either local or staging environment
2. **Test accounts** - Staff user and customer user
3. **Test data** - Orders, devices, clients in system
4. **Physical device** - For push notification testing

### Test Accounts Needed

| Account Type | Purpose |
|--------------|---------|
| Staff user | Test staff app features |
| Customer (single company) | Test simple customer flow |
| Customer (multi company) | Test company selection |

## Test Plan

### Staff App Tests

#### 1. Authentication

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Login with password | Enter credentials, tap Login | Dashboard loads | |
| Login with magic link | Request code, enter code | Dashboard loads | |
| Invalid password | Enter wrong password | Error message shown | |
| Invalid magic code | Enter wrong code | Error message shown | |
| Logout | Tap logout | Returns to login | |
| Session persistence | Force quit, reopen | Still logged in | |
| Token refresh | Wait for token expiry | Seamless refresh | |

#### 2. Dashboard

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Stats load | Navigate to dashboard | Stats cards display | |
| My Queue loads | Scroll to queue section | Assigned devices shown | |
| Stats period change | Change period picker | Stats update | |
| Pull to refresh | Pull down | Data reloads | |

#### 3. Orders

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Order list loads | Navigate to Orders tab | List displays | |
| Order pagination | Scroll to bottom | More orders load | |
| Order search | Enter search term | Filtered results | |
| Order status filter | Select status | Filtered results | |
| Order detail | Tap order | Detail view loads | |
| Client info shows | View order detail | Client name, email, phone | |
| Devices show | View order detail | Device list visible | |

#### 4. Devices

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Device list loads | Navigate to Devices tab | List displays | |
| Device status filter | Select status | Filtered results | |
| Device detail | Tap device | Detail view loads | |
| Device displayName | View any device | Shows combined brand/model | |
| Update status | Change device status | Status updates | |
| Assigned engineer | View device with engineer | Name displays correctly | |

#### 5. Clients

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Client list loads | Navigate to Clients tab | List displays | |
| Client search | Enter search term | Filtered results | |
| Client detail | Tap client | Detail view loads | |
| Client stats | View detail | totalSpend, orderCount show | |
| Client orders | View detail | Orders section shows | |

#### 6. Enquiries

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Enquiry list loads | Navigate to Enquiries tab | List displays | |
| Enquiry status filter | Select status | Filtered results | |
| Enquiry detail | Tap enquiry | Detail view loads | |
| Messages load | View enquiry | Message thread shows | |
| Send reply | Type and send message | Message appears | |
| Mark as read | Open enquiry | Read status updates | |
| Archive | Archive enquiry | Removed from list | |

#### 7. Settings & Push

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Settings load | Navigate to Settings | Options display | |
| Notification prefs load | View notification settings | All toggles show | |
| Toggle preference | Change a toggle | Saves successfully | |
| Push permission | First login on device | Permission dialog | |
| Push received | Send test push | Notification appears | |
| Push tap | Tap notification | Navigates to correct screen | |

### Customer App Tests

#### 8. Customer Authentication

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Request magic link | Enter email, tap send | Success message | |
| Invalid email | Enter bad email | Error message | |
| Verify code | Enter valid code | Login completes | |
| Invalid code | Enter wrong code | Error message | |
| Multi-company selection | Login with multi-company email | Company picker shows | |
| Select company | Pick company | Login completes | |
| Logout | Tap logout | Returns to login | |

#### 9. Customer Orders

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Order list loads | Login, view orders | Customer's orders shown | |
| Order detail loads | Tap order | Full detail with devices, items | |
| Messages in detail | View order with messages | Messages section shows | |
| Send message | Type and send | Message sent, list updates | |

#### 10. Quote Approval

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Quote view | Open order with quote | Items and total shown | |
| Type signature | Select typed, enter name | Name captured | |
| Draw signature | Select drawn, sign | Signature captured | |
| Approve quote | Sign and approve | Status changes to approved | |
| Reject quote | Sign and reject | Status changes to rejected | |
| Cannot re-approve | View approved order | No approve button | |

#### 11. Customer Push

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Push permission | First login | Dialog shown | |
| Order status push | Backend sends push | Notification received | |
| Quote ready push | Backend sends push | Notification received | |
| Tap notification | Tap order push | Opens order detail | |

### Cross-App Tests

#### 12. Staff-Customer Interaction

| Test | Steps | Expected | Pass/Fail |
|------|-------|----------|-----------|
| Staff sends quote | Create quote in staff app | Customer sees in app | |
| Customer approves | Approve in customer app | Staff sees approval | |
| Customer sends message | Message from customer app | Staff sees in enquiry | |
| Staff replies | Reply in staff app | Customer sees in order | |

## Error Checking

### Console Monitoring

During all tests, monitor Xcode console for:
- [ ] No "Failed to decode response" errors
- [ ] No "keyNotFound" errors
- [ ] No "typeMismatch" errors
- [ ] No network timeout errors

### Common Issues to Watch

| Issue | Symptom | Likely Cause |
|-------|---------|--------------|
| Blank screen | View loads but no data | Decode error - check console |
| Wrong data | Data shows but incorrect | Field name mismatch |
| Crash on tap | App crashes opening detail | Missing optional handling |
| Infinite loading | Spinner never stops | API error not caught |

## Test Results Template

```markdown
# Test Results - [Date]

## Staff App

### Authentication
- [x] Login with password - PASS
- [ ] Login with magic link - FAIL: [description]
...

### Issues Found
1. [Issue description]
   - File: `path/to/file.swift`
   - Error: [error message]
   - Fix needed: [what to change]

## Customer App
...

## Summary
- Total tests: XX
- Passed: XX
- Failed: XX
- Blocked: XX

## Next Steps
1. [Action item]
2. [Action item]
```

## Acceptance Checklist

- [ ] All staff app tests pass
- [ ] All customer app tests pass
- [ ] No decode errors in console
- [ ] Push notifications work on both apps
- [ ] Cross-app interactions work
- [ ] No crashes during testing
- [ ] Performance acceptable (no long loading times)

## Deployment

### Final Build Verification

```bash
# Build staff app
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder" \
  -destination "generic/platform=iOS" \
  clean build

# Build customer app
xcodebuild -workspace "Repair Minder/Repair Minder.xcworkspace" \
  -scheme "Repair Minder Customer" \
  -destination "generic/platform=iOS" \
  clean build
```

### Archive for TestFlight

After all tests pass:
1. Increment build number
2. Archive both targets
3. Upload to TestFlight
4. Internal testing
5. External beta (if applicable)

## Handoff Notes

- Document all test results in `test-results.md`
- Any failed tests become bugs to fix
- Create issues for any remaining problems
- This completes the iOS API alignment project
