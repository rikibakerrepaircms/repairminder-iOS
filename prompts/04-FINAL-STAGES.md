# RepairMinder iOS - Final Stages Prompt

Use this prompt **AFTER all parallel stages (06-11) are complete** to generate worker prompts for the final stages.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## Prerequisite Check

Before proceeding, verify these stages are complete:

### For Stage 12 (Customer Portal):
- [ ] Stage 03 (Authentication) ✅
- [ ] Stage 11 (Push Notifications) ✅

### For Stage 15 (Enquiries Module):
- [ ] Stage 07 (Orders Module) ✅
- [ ] Stage 11 (Push Notifications) ✅

### For Stage 13 (Settings & Polish):
- [ ] All stages 01-12 ✅
- [ ] Stage 15 ✅

### For Stage 14 (White-Label):
- [ ] Stage 13 ✅ (or can run in parallel with 13)

---

## Task: Generate Final Stage Prompts

Create worker prompts for:

| Stage | Name | Spec File | Dependencies |
|-------|------|-----------|--------------|
| 12 | Customer Portal | `plans/ios-native-app/12-customer-portal.md` | 03, 11 |
| 15 | Enquiries Module | `plans/ios-native-app/15-enquiries-module.md` | 07, 11 |
| 13 | Settings & Polish | `plans/ios-native-app/13-settings-polish.md` | All |
| 14 | White-Label | `plans/ios-native-app/14-white-label.md` | 13 |

---

## Stage 12 & 15 Can Run in Parallel

Once their dependencies are met, Stage 12 and Stage 15 can be worked on simultaneously.

**Stage 12** creates the Customer Portal (separate app target):
- New target: "Repair Minder Customer"
- Customer login via magic link
- Order tracking with timeline
- Quote approval/rejection
- New enquiry submission

**Stage 15** creates the Staff Enquiries Module:
- EnquiryListView with polished UI
- EnquiryDetailView with conversation
- Quick reply bar with templates
- Convert enquiry to order flow

---

## Customer Portal API Testing

```bash
# Request magic link for customer
curl -s -X POST "https://api.repairminder.com/api/customer/auth/request-magic-link" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com"}' | jq

# Get magic link code from database
npx wrangler d1 execute repairminder_database --remote --json \
  --command "SELECT magic_link_code FROM clients WHERE email = 'rikibaker+customer@gmail.com'" \
  2>/dev/null | jq -r '.[0].results[0].magic_link_code'

# Verify code (replace XXXXXX with code)
curl -s -X POST "https://api.repairminder.com/api/customer/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com", "code": "XXXXXX"}' | jq

# Get customer orders (use customer token)
curl -s "https://api.repairminder.com/api/customer/orders" \
  -H "Authorization: Bearer CUSTOMER_TOKEN" | jq
```

---

## Enquiries API Testing

```bash
# Get all enquiries (staff token)
curl -s "https://api.repairminder.com/api/enquiries" \
  -H "Authorization: Bearer TOKEN" | jq

# Get single enquiry
curl -s "https://api.repairminder.com/api/enquiries/ENQUIRY_ID" \
  -H "Authorization: Bearer TOKEN" | jq

# Reply to enquiry
curl -s -X POST "https://api.repairminder.com/api/enquiries/ENQUIRY_ID/reply" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"message": "Thank you for your enquiry..."}' | jq

# Convert enquiry to order
curl -s -X POST "https://api.repairminder.com/api/enquiries/ENQUIRY_ID/convert" \
  -H "Authorization: Bearer TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"services": ["screen_repair"], "estimatedPrice": 89.99}' | jq
```

---

## Output Format

Generate each prompt in a separate code block:

```markdown
---
## Stage 12: Customer Portal - Worker Prompt
---
```

```
[Stage 12 prompt content]
```

```markdown
---
## Stage 15: Enquiries Module - Worker Prompt
---
```

```
[Stage 15 prompt content]
```

```markdown
---
## Stage 13: Settings & Polish - Worker Prompt
---
```

```
[Stage 13 prompt content]
```

```markdown
---
## Stage 14: White-Label Support - Worker Prompt
---
```

```
[Stage 14 prompt content]
```

---

## Special Notes

### Stage 12 (Customer Portal)
- Creates a **new app target** - this is a separate app
- Shares code from `Core/` and `Shared/`
- Has its own `Customer/` folder for customer-specific views
- Different app icon and branding
- Different bundle identifier

### Stage 15 (Enquiries Module)
- Adds to the **existing staff app**
- New tab in the main tab bar
- Polished, modern UI is a key requirement
- Push notifications for new enquiries

### Stage 13 (Settings & Polish)
- Focus on user experience
- Add loading states everywhere
- Add error states with retry
- Accessibility audit (VoiceOver, Dynamic Type)
- Performance profiling

### Stage 14 (White-Label)
- Creates xcconfig files for brand configuration
- Sets up asset catalogs per brand
- Implements BrandConfiguration.swift
- Documents the process to add new client brands

---

## Project Completion

After Stage 14 is complete, verify:

1. **Staff App** works end-to-end:
   - Login → Dashboard → Orders → Devices → Scanner → Clients → Enquiries → Settings → Logout

2. **Customer Portal** works end-to-end:
   - Login → Orders → Track Order → Approve Quote → New Enquiry → Messages → Logout

3. **White-Label** build works:
   - Build with default branding
   - Build with alternate branding
   - Both apps run independently

4. **App Store Ready**:
   - No crashes
   - No warnings
   - Accessibility verified
   - Performance acceptable

Mark the Master Plan as **COMPLETE** and summarise what was built.
