# Screenshot Capture Prompt

Copy everything below the line into a new Claude Code session to capture all App Store screenshots.

---

## PROMPT START

I need you to capture App Store screenshots for the Repair Minder iOS app across 4 device sizes. This is a methodical task — follow the instructions exactly.

### Project Info

- **Xcode project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/Repair Minder.xcodeproj`
- **Screenshot output directory:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/screenshots/`
- **Scheme:** `Repair Minder`

### Device Matrix

Capture every slide on all 4 devices, in this order:

| Device | Simulator Name | Output suffix |
|---|---|---|
| iPhone 6.5" | iPhone 11 Pro Max | `iphone-6.5.png` |
| iPhone 6.9" | iPhone 16 Pro Max | `iphone-6.9.png` |
| iPad 12.9" | iPad Pro 12.9-inch (2nd generation) | `ipad-12.9.png` |
| iPad 13" | iPad Pro 13-inch (M4) | `ipad-13.png` |

### Login Credentials

| Portal | Email | Magic Link Code |
|---|---|---|
| Staff | `appstore-demo@repairminder.com` | `123456` |
| Customer | `appstore-customer@repairminder.com` | `123456` |

### Status Bar Setup

Before capturing screenshots on each simulator, set a clean status bar:
- Use `mcp__XcodeBuildMCP__sim_statusbar` with `dataNetwork: "wifi"` for a clean wifi indicator.

### Process Per Device

For each of the 4 devices, do the following:

1. **Set session defaults** using `mcp__XcodeBuildMCP__session-set-defaults`:
   - Set `projectPath` to the xcodeproj path
   - Set `scheme` to `Repair Minder`
   - Set `simulatorName` to the device name from the matrix above
   - Set `useLatestOS` to `true`

2. **Build and run** using `mcp__XcodeBuildMCP__build_run_sim`

3. **Wait for the app to load**, then proceed through the capture sequence below.

4. After all slides are captured for this device, move to the next device.

---

### CAPTURE SEQUENCE

For each screenshot, use `mcp__XcodeBuildMCP__screenshot` to capture, then save the resulting image to the correct path.

The login flow uses magic link:
- **Staff login:** On the role selection screen, tap "Staff". Enter email `appstore-demo@repairminder.com`. Submit. On the magic link code screen, enter `123456`. Submit. You should land on the Dashboard.
- **Customer login:** On the role selection screen, tap "Customer". Enter email `appstore-customer@repairminder.com`. Submit. Enter code `123456`. Submit. You should land on the Customer Order List.

Use `mcp__XcodeBuildMCP__describe_ui` before any tap to get accurate coordinates. Use `mcp__XcodeBuildMCP__tap` with either coordinates or accessibility labels to navigate.

#### STAFF SESSION (Slides 1, 3, 4, 5, 6, 9, 2)

**Slide 1 — Dashboard**
- You should already be on the Dashboard after login
- Make sure "This Week" period is selected (tap it if not)
- Scroll to top so the full stats grid is visible
- Screenshot → save to `screenshots/slide-01-dashboard/{device-suffix}`

**Slide 3 — My Queue**
- Tap the "My Queue" tab (second tab in the tab bar)
- Make sure "All" category is selected
- Wait for device list to load
- Screenshot → save to `screenshots/slide-03-queue/{device-suffix}`

**Slide 9 — Device Detail**
- From My Queue, tap the "iPhone 15 Pro" row (Alex Thompson's device)
- Wait for detail view to load
- Scroll so that the status timeline and line items are visible
- Screenshot → save to `screenshots/slide-09-device-detail/{device-suffix}`
- Navigate back to the tab view

**Slide 6 — Order Detail**
- Tap the "Orders" tab (third tab)
- Wait for order list to load
- Tap the first order (should be #100000001 — Alex Thompson, iPhone 15 Pro)
- Wait for order detail to load
- Scroll to show line items and totals
- Screenshot → save to `screenshots/slide-06-order-detail/{device-suffix}`
- Navigate back to the tab view

**Slide 4 — Enquiry List**
- Tap the "Enquiries" tab (fourth tab)
- Wait for enquiry list to load
- Screenshot → save to `screenshots/slide-04-leads/{device-suffix}`

**Slide 5 — Enquiry Detail + AI**
- From the enquiry list, tap Michael Chen's enquiry ("Do you have the back glass in stock?")
- Wait for message thread to load
- Screenshot → save to `screenshots/slide-05-ai-replies/{device-suffix}`
- Navigate back to the tab view

**Slide 2 — Service Type Selection (New Booking)**
- Tap the blue floating action button (FAB) labelled "New Booking" — it should be visible as an overlay on any tab
- Wait for the service type selection screen to appear (showing Repair, Buyback, Accessories, Device Sale cards)
- Screenshot → save to `screenshots/slide-02-service-types/{device-suffix}`
- Dismiss/close the booking screen

**Slide 10 — Security (Passcode Lock)**
- Navigate to the "More" tab (fifth tab / Settings)
- Find and tap "Passcode & Security" or similar passcode settings
- Set up a passcode if not already set (use `1234` or `123456`)
- After passcode is set, trigger the lock screen:
  - Press the home button using `mcp__XcodeBuildMCP__button` with `buttonType: "home"`
  - Then reopen the app by tapping it, or use `mcp__XcodeBuildMCP__launch_app_sim` with the bundle ID `com.mendmyi.repairminder`
- Wait for the passcode lock screen to appear
- Screenshot → save to `screenshots/slide-10-security/{device-suffix}`
- Enter the passcode to unlock

#### LOG OUT OF STAFF

- Navigate to More/Settings tab
- Tap "Log Out" and confirm
- You should return to the role selection screen

#### CUSTOMER SESSION (Slides 7, 8)

**Slide 7 — Customer Order List**
- Tap "Customer" on the role selection screen
- Enter email `appstore-customer@repairminder.com`, submit
- Enter code `123456`, submit
- If a company selection screen appears, select the demo company
- You should land on the Customer Order List showing 3 sections (Action Required, In Progress, Completed)
- Screenshot → save to `screenshots/slide-07-customer-portal/{device-suffix}`

**Slide 8 — Quote Approval**
- Tap the order in the "Action Required" section (iPad Air battery order)
- Wait for order detail to load
- Make sure the "Action Required" banner and "Approve" button are visible
- Screenshot → save to `screenshots/slide-08-approval/{device-suffix}`

#### LOG OUT OF CUSTOMER

- Navigate back, find the profile/logout option
- Log out so the app is clean for the next device

---

### OUTPUT STRUCTURE

When complete, the directory should look like this:

```
screenshots/
├── slide-01-dashboard/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-02-service-types/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-03-queue/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-04-leads/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-05-ai-replies/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-06-order-detail/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-07-customer-portal/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-08-approval/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
├── slide-09-device-detail/
│   ├── iphone-6.5.png
│   ├── iphone-6.9.png
│   ├── ipad-12.9.png
│   └── ipad-13.png
└── slide-10-security/
    ├── iphone-6.5.png
    ├── iphone-6.9.png
    ├── ipad-12.9.png
    └── ipad-13.png
```

That's **40 screenshots total** (10 slides x 4 devices).

### IMPORTANT NOTES

- Use `describe_ui` before EVERY tap to get accurate element positions. Never guess coordinates.
- After each screenshot capture, the MCP returns an image. Save it using Bash: `cp <source_path> <destination_path>` — the screenshot tool returns a file path.
- If login fails or a screen doesn't load, wait a few seconds and retry.
- For iPads, the app may show a different layout (sidebar vs tabs). Adapt navigation accordingly but capture the same content.
- Keep the status bar clean — no "Carrier" text, wifi icon visible.
- Do NOT dismiss any alerts or banners that are part of the app UI (like "Action Required") — those are intentional.
- Process one device at a time, completing all 10 slides before moving to the next device.
- After completing all 4 devices, run `ls -R /Volumes/Riki\ Repos/repairminder-iOS/repairminder-iOS/screenshots/` to verify all 40 files are present and report back.
