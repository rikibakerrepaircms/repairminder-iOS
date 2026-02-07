# Riki To Do — App Store Submission

These are the remaining manual tasks before submission.

---

## Web Pages (repairminder.com)

- [x] ~~**repairminder.com**~~ — LIVE (coming soon landing page)
- [x] ~~**repairminder.com/privacy-policy**~~ — LIVE. Must cover these 13 declared data types:
  - **Contact Info:** Name, Email Address, Phone Number, Physical Address
  - **Financial Info:** Payment Info (card brand/last 4 via Stripe/Square), Other Financial Info (order totals, line items, refunds)
  - **User Content:** Photos/Videos (device images), Customer Support (ticket messages, enquiries), Other User Content (repair notes, diagnostic notes)
  - **Identifiers:** User ID, Device ID (APNs token)
  - **Purchases:** Purchase History (repair order history)
  - **Usage Data:** Product Interaction (audit logs)
  - All collected for **App Functionality only** (no analytics, no advertising, no tracking)
  - All **linked to identity** (authenticated users)
  - How data is stored (Cloudflare D1/Workers, images via R2)
  - Push notification usage (APNs)
  - No third-party analytics/tracking SDKs
  - Data retention and deletion policy
  - Contact email for privacy inquiries
  - GDPR compliance section (if serving EU users)
  - Note: App does NOT allow account creation (B2B — accounts created via web dashboard)
- [x] ~~**repairminder.com/terms**~~ — LIVE (Terms of Service)
- [x] ~~**repairminder.com/support**~~ — LIVE (Support page with FAQ + contact email)

## Screenshots (Stage 3)

- [ ] Design branded screenshot templates (phone frame + caption text)
- [ ] Capture and export screenshots for **6.7"** (1290x2796) and **6.5"** (1242x2688)
- [ ] Minimum 3, recommended 6-8 screenshots showing key screens
- [ ] Upload via CLI (`asc assets upload`) or App Store Connect web UI

## Demo Environment (Stage 4)

- [x] ~~Backend: Implement static magic code (`123456`) bypass for demo accounts~~ — deployed in email.js + customer-auth.js
- [x] ~~Backend: Create demo company + staff user + customer user + seed data~~ — 1 company, 5 clients, 7 orders, 8 devices, 3 enquiries
- [x] ~~Test both staff and customer demo login flows end-to-end~~ — verified on simulator, both work

## Final Build (only if code changes are needed)

- [ ] If demo environment requires iOS changes, archive and upload a new build
- [ ] Re-attach new build to version (Claude can do this via CLI)

---

## Already Done (by Claude via CLI)

- [x] ~~Categories set: BUSINESS + UTILITIES~~
- [x] ~~Age rating: all NONE, messagingAndChat=true~~
- [x] ~~Description, keywords, promotional text uploaded~~
- [x] ~~Subtitle: "Repair Shop Management"~~
- [x] ~~Privacy policy URL: repairminder.com/privacy-policy~~
- [x] ~~Support URL: repairminder.com/support~~
- [x] ~~Marketing URL: repairminder.com~~
- [x] ~~Build 10 attached to iOS version~~
- [x] ~~Encryption declaration created~~
- [x] ~~Review details created (contact info + demo credentials + review notes)~~
- [x] ~~Pricing set to Free (USD base territory)~~
- [x] ~~Privacy declarations audited (13 data types, all correct, no changes needed)~~
- [x] ~~PrivacyInfo.xcprivacy matches App Store Connect declarations~~
- [x] ~~Privacy policy URL confirmed: repairminder.com/privacy-policy~~

## Still Need Claude For (ask when ready)

- [ ] **Upload screenshots** — once you provide the image files
- [ ] **Submit for review** — the final submission step after all blockers resolved
- [ ] **Update review notes** — if demo credentials or instructions change
