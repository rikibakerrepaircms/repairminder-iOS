# RepairMinder Project Rules

## CRITICAL RULES FOR ALL CLAUDE WORKERS

**These rules are MANDATORY. Follow them exactly.**

### Rule 1: Token Management (CRITICAL - READ CAREFULLY)

**STOP! Before generating a new token:**

1. **FIRST**: Read the "Current Valid Tokens" section below
2. **SECOND**: Check if the token is expired by comparing `Expires` timestamp to current time
3. **THIRD**: If NOT expired, **TRY THE TOKEN FIRST** by making a test API call
4. **ONLY IF** the token is expired or fails authentication, generate a new one

**Token Testing Command:**
```bash
curl -s "https://api.repairminder.com/api/dashboard/stats" -H "Authorization: Bearer <TOKEN>" | jq '.success'
```
If this returns `true`, the token is valid - USE IT!

**When you must generate a new token:**
- Generate using the steps in "How to Generate a New Token"
- **IMMEDIATELY update this file** with the new token details
- Include: Last Updated timestamp, Expires timestamp (15 min from now), User email, Role

**WHY**:
- Tokens have a 15-minute TTL (short-lived for security)
- Generating tokens sends emails and triggers rate limits
- Rate limits block ALL logins from your IP for 15 minutes
- Reusing valid tokens avoids these problems

### Rule 2: Test Data Company

When creating test orders, devices, clients, or any other test data:

1. **ALWAYS use the "repairminder" company** (Company ID: `4b63c1e6ade1885e73171e10221cac53`)
2. **DO NOT use "mendmyi"** or other companies for test data
3. Use tokens from `rikibaker+admin@gmail.com` or `rikibaker+repairminder@gmail.com` for creating test data

**WHY**: The "repairminder" company is designated for testing. Other companies like "mendmyi" are for production use or specific feature testing only.

---

## Recent Fixes & Updates

### SMS Not Sending for Device Status Changes (2026-01-15) ✅ RESOLVED

**Issue:** SMS messages were not being sent when device statuses changed (e.g., device_received, repaired_ready).

**Root Cause:** SQL query in `sendDeviceStatusSms()` tried to SELECT non-existent column `d.display_name` from `order_devices` table, causing silent failures.

**Fixed Files:**
- `worker/src/order-sms-triggers.js` - Removed non-existent column, fixed device name building
- `worker/src/stage-messages.js` - Improved error logging, fixed template data properties

**See Full Details:** [SMS-FIX-2026-01-15.md](./SMS-FIX-2026-01-15.md)

**Verification:** Run `./verify-sms.sh` after creating orders or changing device statuses to confirm SMS is working.

---

## Current Valid Tokens (24hr expiry)

**⚠️ REUSE THESE TOKENS UNTIL EXPIRED - DO NOT GENERATE NEW ONES UNNECESSARILY**

Check expiry dates below. Only generate new tokens if these are expired.

### Master Admin Token

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-02-01 19:31 UTC |
| **Expires** | 2026-02-01 19:46 UTC (short-lived, regenerate as needed) |
| **User** | rikibaker+repairminder@gmail.com |
| **Role** | master_admin |
| **Status** | ⚠️ SHORT-LIVED - Regenerate as needed |

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiIxYjhlNjE4MTE1OTAxYzZkZTk4YzI5Y2I3YjlmZmM0NyIsImNvbXBhbnlJZCI6IjRiNjNjMWU2YWRlMTg4NWU3MzE3MWUxMDIyMWNhYzUzIiwicm9sZSI6Im1hc3Rlcl9hZG1pbiIsInBoaUFjY2Vzc0xldmVsIjoiZnVsbCIsImlzTW9iaWxlIjpmYWxzZSwiaXNzdWVkQXQiOjE3Njk5NzM0ODIsImRhdGFDbGFzc2lmaWNhdGlvbiI6InB1YmxpYyIsInNlc3Npb25JZCI6IjMzMDQ3YTkwLTA0OTktNDM5Yi04Nzk3LWJiYzhhMjBiOTkxZCIsImNvbXBhbnlDb250ZXh0Ijp7ImlkIjoiNGI2M2MxZTZhZGUxODg1ZTczMTcxZTEwMjIxY2FjNTMiLCJyb2xlIjoibWFzdGVyX2FkbWluIiwicGVybWlzc2lvbnMiOltdfSwiaWF0IjoxNzY5OTczNDgyLCJleHAiOjE3Njk5NzQzODIsImlzcyI6Imh0dHBzOi8vYXBpLnJlcGFpcm1pbmRlci5jb20iLCJhdWQiOiJodHRwczovL2FwcC5yZXBhaXJtaW5kZXIuY29tIiwianRpIjoiODRiMTk2Y2ItOTMzMy00ZTAyLTkzZTQtOWFiNmNmYjFhNzkwIn0.2QVQCmW6FnrwFcLTe0pLgK_zF64eh8dIg3UHFcIeGYk
```

### Admin Token

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-02-03 00:11 UTC |
| **Expires** | 2026-02-03 00:26 UTC (15 min TTL) |
| **User** | rikibaker+admin@gmail.com |
| **Role** | admin |
| **Company ID** | 4b63c1e6ade1885e73171e10221cac53 |
| **Status** | ⚠️ SHORT-LIVED - Check expiry before using |

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI0YmM1OGViODYyNjE0ZTFlOWZjMmU0MGZlZGE4NTVmMyIsImNvbXBhbnlJZCI6IjRiNjNjMWU2YWRlMTg4NWU3MzE3MWUxMDIyMWNhYzUzIiwicm9sZSI6ImFkbWluIiwicGhpQWNjZXNzTGV2ZWwiOiJmdWxsIiwiaXNNb2JpbGUiOmZhbHNlLCJpc3N1ZWRBdCI6MTc3MDA3NzQ1OCwiZGF0YUNsYXNzaWZpY2F0aW9uIjoiY29uZmlkZW50aWFsIiwic2Vzc2lvbklkIjoiMzRjMDlkNTQtMDhhOC00ZTYyLWI1MmQtODM5MDNkYWI1OTcxIiwiY29tcGFueUNvbnRleHQiOnsiaWQiOiI0YjYzYzFlNmFkZTE4ODVlNzMxNzFlMTAyMjFjYWM1MyIsInJvbGUiOiJhZG1pbiIsInBlcm1pc3Npb25zIjpbXX0sImlhdCI6MTc3MDA3NzQ1OCwiZXhwIjoxNzcwMDc4MzU4LCJpc3MiOiJodHRwczovL2FwaS5yZXBhaXJtaW5kZXIuY29tIiwiYXVkIjoiaHR0cHM6Ly9hcHAucmVwYWlybWluZGVyLmNvbSIsImp0aSI6IjU2ZDkyN2M0LTRlNjgtNGIxYy1iNmUzLThmNzIzMDZiNWU3YyJ9.COB1XjuaKi57ngvjigqmkOIPHv8x4gVDmD_mAJmh_gc
```

> **REMINDER**: If you generate a new token, you MUST update this file with the new token, timestamps, and role. See "Rule 1: Token Management" at the top of this file.

### Mendmyi Admin Token (Custom Email Feature Enabled)

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-02-03 15:04 UTC |
| **Expires** | 2026-02-03 15:19 UTC (15 min TTL) |
| **User** | riki+repairminder@mendmyi.com |
| **Role** | admin |
| **Company ID** | a12a4d58448c4b3abe120826303280c1 |
| **Note** | This company has custom_email_enabled=1 |
| **Status** | ⚠️ SHORT-LIVED - Check expiry before using |

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiJlY2RkMGNjYTlmNDI0YTdjODM0MzQ5M2ExNGUyNTQxOSIsImNvbXBhbnlJZCI6ImExMmE0ZDU4NDQ4YzRiM2FiZTEyMDgyNjMwMzI4MGMxIiwicm9sZSI6ImFkbWluIiwicGhpQWNjZXNzTGV2ZWwiOiJmdWxsIiwiaXNNb2JpbGUiOmZhbHNlLCJpc3N1ZWRBdCI6MTc3MDEzMTA4NywiZGF0YUNsYXNzaWZpY2F0aW9uIjoiY29uZmlkZW50aWFsIiwic2Vzc2lvbklkIjoiM2ZhZjNmOTItZTY3Mi00Y2Q5LWI4NDUtZDU3MjNlOTViZDg3IiwiY29tcGFueUNvbnRleHQiOnsiaWQiOiJhMTJhNGQ1ODQ0OGM0YjNhYmUxMjA4MjYzMDMyODBjMSIsInJvbGUiOiJhZG1pbiIsInBlcm1pc3Npb25zIjpbXX0sImlhdCI6MTc3MDEzMTA4NywiZXhwIjoxNzcwMTMxOTg3LCJpc3MiOiJodHRwczovL2FwaS5yZXBhaXJtaW5kZXIuY29tIiwiYXVkIjoiaHR0cHM6Ly9hcHAucmVwYWlybWluZGVyLmNvbSIsImp0aSI6ImEwODBlNjkxLWQyNDEtNGZjNC05YWZkLWFhNjM1ZmMwMDhhOSJ9.ZONkyqxSiZOsp9jD52cYt0U0PZqqOo3nabay-DPitjM
```

### Senior Engineer Token

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-01-12 11:28 UTC |
| **Expires** | 2026-01-13 11:28 UTC |
| **User** | rikibaker+linda@gmail.com |
| **Role** | senior_engineer |
| **Company ID** | 4b63c1e6ade1885e73171e10221cac53 |
| **Status** | ✅ VALID |
| **Note** | Use for testing restricted role access |

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiI0NjA2MDdmZDNmY2Q0YzEwOWIyODI1MWRmNWViMmUxOSIsImNvbXBhbnlJZCI6IjRiNjNjMWU2YWRlMTg4NWU3MzE3MWUxMDIyMWNhYzUzIiwicm9sZSI6InNlbmlvcl9lbmdpbmVlciIsInBoaUFjY2Vzc0xldmVsIjoiZnVsbCIsImlzTW9iaWxlIjpmYWxzZSwiaXNzdWVkQXQiOjE3NjgyMTcyNzcsImRhdGFDbGFzc2lmaWNhdGlvbiI6InB1YmxpYyIsInNlc3Npb25JZCI6IjY5NjBlYmNhLTFlMDctNDJhNi1iZGNhLTUxYTMyZDBjNWQzMCIsImNvbXBhbnlDb250ZXh0Ijp7ImlkIjoiNGI2M2MxZTZhZGUxODg1ZTczMTcxZTEwMjIxY2FjNTMiLCJyb2xlIjoic2VuaW9yX2VuZ2luZWVyIiwicGVybWlzc2lvbnMiOltdfSwiaWF0IjoxNzY4MjE3Mjc3LCJleHAiOjE3NjgzMDM2NzcsImlzcyI6Imh0dHBzOi8vYXBpLnJlcGFpcm1pbmRlci5jb20iLCJhdWQiOiJodHRwczovL2FwcC5yZXBhaXJtaW5kZXIuY29tIiwianRpIjoiYjMwYjY0ZmYtNWU3NC00MWQ2LWFkM2YtYjY4ZGUyN2ExMDk1In0.eOJiPv8FifgJ0LNRj6eS2_iBRFGlHzF6b0clORPoYMs
```

### Engineer Token

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-01-13 17:30 UTC |
| **Expires** | 2026-01-14 17:30 UTC |
| **User** | rikibaker+engineer@gmail.com |
| **Role** | engineer |
| **Company ID** | 4b63c1e6ade1885e73171e10221cac53 |
| **Status** | ✅ VALID |
| **Note** | Most restricted role - only dashboard, active_queue, settings, booking access |

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiJmZjU4Y2M5ZTJlMTIyZTM3Y2EyYmU0ZmIzNTI0Y2QxMyIsImNvbXBhbnlJZCI6IjRiNjNjMWU2YWRlMTg4NWU3MzE3MWUxMDIyMWNhYzUzIiwicm9sZSI6ImVuZ2luZWVyIiwicGhpQWNjZXNzTGV2ZWwiOiJmdWxsIiwiaXNNb2JpbGUiOmZhbHNlLCJpc3N1ZWRBdCI6MTc2ODMyNTQyOSwiZGF0YUNsYXNzaWZpY2F0aW9uIjoicHVibGljIiwic2Vzc2lvbklkIjoiYWYzMWYwNjUtNTk0ZS00ZWFlLTlkNWYtYjY0YTgxZjVkYmZlIiwiY29tcGFueUNvbnRleHQiOnsiaWQiOiI0YjYzYzFlNmFkZTE4ODVlNzMxNzFlMTAyMjFjYWM1MyIsInJvbGUiOiJlbmdpbmVlciIsInBlcm1pc3Npb25zIjpbXX0sImlhdCI6MTc2ODMyNTQyOSwiZXhwIjoxNzY4NDExODI5LCJpc3MiOiJodHRwczovL2FwaS5yZXBhaXJtaW5kZXIuY29tIiwiYXVkIjoiaHR0cHM6Ly9hcHAucmVwYWlybWluZGVyLmNvbSIsImp0aSI6IjU5MTJhZDJiLTczMDQtNDk4Yy05NjhmLWQxZWJlYWMzODY0MCJ9.7_Wc6S9GT4VhYirPehHqHD0gfQID5Myk1KSLLFthhnI
```

### Office Token

| Field | Value |
|-------|-------|
| **Last Updated** | 2026-01-12 12:41 UTC |
| **Expires** | 2026-01-13 12:41 UTC |
| **User** | rikibaker+office@gmail.com |
| **Role** | office |
| **Company ID** | 4b63c1e6ade1885e73171e10221cac53 |
| **Status** | ✅ VALID |
| **Note** | Office staff - orders, clients, enquiries, products access |

```
eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiJmNGI4NDRiM2JiMzcyZDY5NjIyOWM3NGM5YjcyYjhlMyIsImNvbXBhbnlJZCI6IjRiNjNjMWU2YWRlMTg4NWU3MzE3MWUxMDIyMWNhYzUzIiwicm9sZSI6Im9mZmljZSIsInBoaUFjY2Vzc0xldmVsIjoiZnVsbCIsImlzTW9iaWxlIjpmYWxzZSwiaXNzdWVkQXQiOjE3NjgyMjA0ODksImRhdGFDbGFzc2lmaWNhdGlvbiI6InB1YmxpYyIsInNlc3Npb25JZCI6IjQ1NjQ2Mzc2LTgzNmItNGVlNC1hYzg0LTg3NzdjYzZlODg3OCIsImNvbXBhbnlDb250ZXh0Ijp7ImlkIjoiNGI2M2MxZTZhZGUxODg1ZTczMTcxZTEwMjIxY2FjNTMiLCJyb2xlIjoib2ZmaWNlIiwicGVybWlzc2lvbnMiOltdfSwiaWF0IjoxNzY4MjIwNDg5LCJleHAiOjE3NjgzMDY4ODksImlzcyI6Imh0dHBzOi8vYXBpLnJlcGFpcm1pbmRlci5jb20iLCJhdWQiOiJodHRwczovL2FwcC5yZXBhaXJtaW5kZXIuY29tIiwianRpIjoiYzZjZjljM2YtOTYxNS00OWNhLWE1MjgtY2ZhZjg4MzY0NjAwIn0.4lrgV5kmY2lfzzFkialAL7EfcqZqAdNUodcwRyjjSas
```

### Customer Portal Token

| Field | Value |
|-------|-------|
| **Last Updated** | 2025-12-28 14:34 UTC |
| **Expires** | 2025-12-29 14:34 UTC |
| **Client Email** | rikibaker+customer@gmail.com |
| **Type** | customer_portal |

```
eyJhbGciOiJIUzI1NiJ9.eyJ0eXBlIjoiY3VzdG9tZXIiLCJjbGllbnRJZCI6ImQ1MmZhZDIyLTRkYmUtNDA4Yy05MGMxLTQyYzhiMTk1NDMyZCIsImNvbXBhbnlJZCI6IjRiNjNjMWU2YWRlMTg4NWU3MzE3MWUxMDIyMWNhYzUzIiwiZW1haWwiOiJyaWtpYmFrZXIrY3VzdG9tZXJAZ21haWwuY29tIiwic2NvcGUiOiJjdXN0b21lcl9wb3J0YWwiLCJpc3N1ZWRBdCI6MTc2NjkzMjQ4Miwic2Vzc2lvbklkIjoiZDhjY2EyZjAtNTUzZi00YjJjLWE0MWQtYWViN2IxZThjZTdkIiwiaWF0IjoxNzY2OTMyNDgyLCJleHAiOjE3NjcwMTg4ODIsImlzcyI6Imh0dHBzOi8vYXBpLnJlcGFpcm1pbmRlci5jb20iLCJhdWQiOiJodHRwczovL2FwcC5yZXBhaXJtaW5kZXIuY29tIiwianRpIjoiZDhjY2EyZjAtNTUzZi00YjJjLWE0MWQtYWViN2IxZThjZTdkIn0.sJgVUT8356UYamimuEGDcsacROOGMPGhGVxXbyH1YjY
```

---

## Project Overview

RepairMinder is a multi-tenant SaaS application for repair service management.

- **Frontend**: React + TypeScript + Vite (in `/src`)
- **Backend**: Cloudflare Worker (in `/worker`)
- **Database**: Cloudflare D1 (SQLite)
- **API URL**: `https://api.repairminder.com`
- **App URL**: `https://app.repairminder.com`

---

## How to Use the Token for API Testing

**CRITICAL**: When using curl, paste the token DIRECTLY into the command. Do NOT use shell variables - they don't work reliably with long JWT tokens.

### Correct Way (paste token directly)

```bash
curl -s "https://api.repairminder.com/api/dashboard/stats" \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOi..." | jq
```

### Wrong Way (shell variables fail silently)

```bash
# DO NOT DO THIS - the token gets truncated/lost
TOKEN="eyJhbGciOiJIUzI1NiJ9..."
curl -s "https://api.repairminder.com/api/endpoint" -H "Authorization: Bearer $TOKEN"
```

---

## How to Generate a New Token (Only if Expired)

Follow these steps EXACTLY in order. Each step must complete before the next.

### Step 1: Request a magic link code

Run this command:

```bash
curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/request" -H "Content-Type: application/json" -d '{"email": "rikibaker+admin@gmail.com"}'
```

You should see: `{"success":true,"data":{"message":"Magic link sent to your email"}}`

### Step 2: Get the 6-digit code from the database

Run this command:

```bash
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM users WHERE email = 'rikibaker+admin@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'
```

This outputs a 6-digit code like `842038`. Copy this code.

### Step 3: Exchange the code for a JWT token

Replace `XXXXXX` with the 6-digit code from Step 2:

```bash
curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/verify-code" -H "Content-Type: application/json" -d '{"email": "rikibaker+admin@gmail.com", "code": "XXXXXX"}'
```

The response JSON contains `data.token` - this is your JWT token.

To extract just the token:

```bash
curl -s -X POST "https://api.repairminder.com/api/auth/magic-link/verify-code" -H "Content-Type: application/json" -d '{"email": "rikibaker+admin@gmail.com", "code": "XXXXXX"}' | jq -r '.data.token'
```

### Step 4: Update this file

After getting a new token, UPDATE the "Current Valid Token" section at the top of this file with:
- The new token
- Current UTC timestamp as "Last Updated"
- Expiry time (24 hours from now)
- User email and role

---

## How to Generate a Customer Portal Token

Customer portal tokens authenticate customers to view/approve their orders. Use these for testing `/api/customer/*` endpoints.

### Step 1: Request a magic link code

```bash
curl -s -X POST "https://api.repairminder.com/api/customer/auth/request-magic-link" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com"}'
```

### Step 2: Get the 6-digit code from the database

```bash
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT magic_link_code FROM clients WHERE email = 'rikibaker+customer@gmail.com'" 2>/dev/null | jq -r '.[0].results[0].magic_link_code'
```

### Step 3: Exchange the code for a JWT token

Replace `XXXXXX` with the 6-digit code:

```bash
curl -s -X POST "https://api.repairminder.com/api/customer/auth/verify-code" \
  -H "Content-Type: application/json" \
  -d '{"email": "rikibaker+customer@gmail.com", "code": "XXXXXX"}' | jq -r '.data.token'
```

### Step 4: Update this file

Update the "Customer Portal Token" section with the new token and timestamps.

---

## Test Users

| Email | Type | Company | Use For |
|-------|------|---------|---------|
| `rikibaker+repairminder@gmail.com` | master_admin | RepairMinder | Full system access, cross-company |
| `rikibaker+admin@gmail.com` | admin | RepairMinder | Admin API testing |
| `riki+repairminder@mendmyi.com` | admin | mendmyi | Cross-company isolation testing |
| `rikibaker+linda@gmail.com` | senior_engineer | RepairMinder | Restricted role testing |
| `rikibaker+engineer@gmail.com` | engineer | RepairMinder | Most restricted role testing |
| `rikibaker+office@gmail.com` | office | RepairMinder | Office staff role testing |
| `rikibaker+customer@gmail.com` | customer_portal | RepairMinder | Customer portal API testing |

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| "Authentication required" error | Token expired. Generate a new one using steps above. |
| Code expired (15 min limit) | Run Step 1 again to get a fresh code. |
| Empty response from curl | Make sure you're pasting the token directly, not using a variable. |
| Token looks truncated | JWT tokens are long. Copy the ENTIRE token from the code block above. |
| "Too many login attempts" error | Rate limited. See "Clearing Rate Limits" section below. |

---

## Clearing Rate Limits

If you hit the "Too many login attempts" error, you can clear the rate limit manually.

**Step 1: Get your IP address (as seen by Cloudflare)**

The rate limit is keyed by IP. Find your IP address:

```bash
curl -s https://api.repairminder.com/api/health | jq -r '.data.clientIp'
```

Or if that doesn't work:

```bash
curl -s https://ifconfig.me
```

**Step 2: Delete the rate limit key from KV**

Replace `YOUR_IP_ADDRESS` with your actual IP:

```bash
npx wrangler kv key delete "ratelimit:login:YOUR_IP_ADDRESS" --namespace-id=57411dc0d8ef442db466a4e74c59ebb2
```

Example:
```bash
npx wrangler kv key delete "ratelimit:login:86.140.38.182" --namespace-id=57411dc0d8ef442db466a4e74c59ebb2
```

**Step 3: Retry your token generation**

After clearing the rate limit, you can generate a new token using the steps above.

---

## Database Access

Use wrangler to query the D1 database:

```bash
npx wrangler d1 execute repairminder_database --remote --command "YOUR_SQL"
```

For JSON output (useful for parsing):

```bash
npx wrangler d1 execute repairminder_database --remote --json --command "YOUR_SQL"
```

---

## Available User Roles

| Role | Access Level |
|------|--------------|
| `master_admin` | Full system access, all companies |
| `admin` | Company administrator - full company access |
| `senior_engineer` | Enhanced engineer with more page access |
| `engineer` | Basic engineer - active_queue, dashboard, settings, booking |
| `office` | Office staff - orders, clients, enquiries, products |
| `technician` | Similar to engineer (legacy role name) |

---

## Cloudflare Deployments (Workers, Pages, D1, R2)

### Authentication

Wrangler uses OAuth for authentication. Run `npx wrangler login` to authenticate via browser. Credentials are stored automatically.

### Deploy Worker (Backend API)

The worker is in `/worker`. To deploy:

```bash
cd /Users/riki/repairminder/worker && npx wrangler deploy
```

This deploys to `https://api.repairminder.com` (via custom domain).

**Output shows:**
- Upload size
- Bound resources (D1, R2, KV, etc.)
- Version ID
- Triggers (schedules, routes)

### Deploy Pages (Frontend)

The frontend builds to `/dist`. To deploy:

```bash
# First build the frontend
npm run build

# Then deploy to Pages
npx wrangler pages deploy dist --project-name=repairminder-dashboard
```

This deploys to `https://app.repairminder.com` (via custom domain).

**Pages Projects:**
| Project | Domain |
|---------|--------|
| `repairminder-dashboard` | app.repairminder.com |
| `repairminder-docs` | docs.repairminder.com |

To list all Pages projects:

```bash
npx wrangler pages project list
```

### D1 Database

D1 is Cloudflare's SQLite database.

**Query the database:**

```bash
npx wrangler d1 execute repairminder_database --remote --command "SELECT * FROM users LIMIT 5"
```

**Get JSON output (for parsing):**

```bash
npx wrangler d1 execute repairminder_database --remote --json --command "SELECT * FROM users LIMIT 5"
```

**Run a migration:**

```bash
npx wrangler d1 execute repairminder_database --remote --file worker/migrations/XXXX_migration_name.sql
```

**List tables:**

```bash
npx wrangler d1 execute repairminder_database --remote --command "SELECT name FROM sqlite_master WHERE type='table'"
```

### R2 Storage

R2 is Cloudflare's object storage.

**Buckets:**
| Bucket | Purpose |
|--------|---------|
| `repairminder-data` | General data storage |
| `repairminder-device-images` | Device photos |
| `repairminder-assets` | Static assets |

**List objects in a bucket:**

```bash
npx wrangler r2 object list repairminder-data
```

**Upload a file:**

```bash
npx wrangler r2 object put repairminder-data/path/to/file.txt --file ./local-file.txt
```

**Download a file:**

```bash
npx wrangler r2 object get repairminder-data/path/to/file.txt --file ./downloaded.txt
```

**Delete a file:**

```bash
npx wrangler r2 object delete repairminder-data/path/to/file.txt
```

### KV Namespace

KV is Cloudflare's key-value storage (used for rate limiting).

**List keys:**

```bash
npx wrangler kv:key list --namespace-id=57411dc0d8ef442db466a4e74c59ebb2
```

**Get a value:**

```bash
npx wrangler kv:key get "key-name" --namespace-id=57411dc0d8ef442db466a4e74c59ebb2
```

### Worker Secrets

Secrets are stored securely and accessed via `env.SECRET_NAME` in the worker.

**List secrets:**

```bash
npx wrangler secret list
```

**Add/update a secret:**

```bash
echo "secret-value" | npx wrangler secret put SECRET_NAME
```

### Viewing Logs

**Tail live logs from production:**

```bash
npx wrangler tail
```

**Filter by status:**

```bash
npx wrangler tail --status error
```

---

## Key Files

- `worker/index.js` - Main API router
- `worker/src/auth.js` - Authentication service
- `worker/src/middleware/authorization.js` - Role-based access control
- `worker/src/database.js` - Database operations
- `worker/wrangler.toml` - Worker configuration (bindings, routes, etc.)
