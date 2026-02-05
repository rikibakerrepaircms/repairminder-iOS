# Stage 01 — Backend: Database & API

## Objective

Add passcode fields to the users table and create API endpoints for setting, verifying, and resetting user passcodes.

## Dependencies

None — this is the foundation stage.

## Complexity

**Medium** — Database migration, 7 new API endpoints, email template, password hashing.

---

## Files to Create

### `worker/migrations/0268_add_passcode_fields.sql`

```sql
-- Add passcode fields to users table
ALTER TABLE users ADD COLUMN passcode_hash TEXT;
ALTER TABLE users ADD COLUMN passcode_salt TEXT;
ALTER TABLE users ADD COLUMN passcode_enabled INTEGER DEFAULT 0;
ALTER TABLE users ADD COLUMN passcode_timeout_minutes INTEGER DEFAULT 15;
ALTER TABLE users ADD COLUMN passcode_reset_token TEXT;
ALTER TABLE users ADD COLUMN passcode_reset_expires DATETIME;
```

**Notes:**
- All columns nullable/defaulted — existing users get `NULL` hash (no passcode set), `passcode_enabled = 0`
- `passcode_enabled` is separate from having a hash — user can set a passcode then disable lock without deleting it
- `passcode_timeout_minutes` defaults to 15
- `passcode_reset_token` + `passcode_reset_expires` used for email reset flow

---

## Files to Modify

### `worker/src/database.js`

**Add methods:**

```javascript
// Check if user has passcode set
async hasPasscode(userId) {
    const result = await this.db.prepare(
        'SELECT passcode_hash FROM users WHERE id = ? AND deleted_at IS NULL'
    ).bind(userId).first();
    return !!(result && result.passcode_hash);
}

// Set user passcode (hash + salt done at API layer)
async setUserPasscode(userId, passcodeHash, passcodeSalt) {
    return await this.db.prepare(
        'UPDATE users SET passcode_hash = ?, passcode_salt = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).bind(passcodeHash, passcodeSalt, userId).run();
}

// Get user passcode hash + salt for verification
async getUserPasscode(userId) {
    return await this.db.prepare(
        'SELECT passcode_hash, passcode_salt FROM users WHERE id = ? AND deleted_at IS NULL'
    ).bind(userId).first();
}

// Get/set passcode timeout
async getPasscodeTimeout(userId) {
    const result = await this.db.prepare(
        'SELECT passcode_timeout_minutes FROM users WHERE id = ? AND deleted_at IS NULL'
    ).bind(userId).first();
    return result?.passcode_timeout_minutes ?? 15;
}

async setPasscodeTimeout(userId, minutes) {
    return await this.db.prepare(
        'UPDATE users SET passcode_timeout_minutes = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).bind(minutes, userId).run();
}

// Passcode reset token management
async setPasscodeResetToken(userId, token, expires) {
    return await this.db.prepare(
        'UPDATE users SET passcode_reset_token = ?, passcode_reset_expires = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).bind(token, expires, userId).run();
}

async getUserByPasscodeResetToken(token) {
    return await this.db.prepare(
        'SELECT * FROM users WHERE passcode_reset_token = ? AND passcode_reset_expires > CURRENT_TIMESTAMP AND deleted_at IS NULL'
    ).bind(token).first();
}

async clearPasscodeResetToken(userId) {
    return await this.db.prepare(
        'UPDATE users SET passcode_reset_token = NULL, passcode_reset_expires = NULL, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).bind(userId).run();
}
```

### `worker/src/auth.js`

**⚠️ IMPORTANT: The code snippets below are pseudo-code showing the LOGIC. The actual codebase uses different patterns:**
- **Routes**: Inline URL pattern matching in the main fetch handler (NOT `router.post()`)
- **User access**: Explicit `authService.getUserFromToken(token)` (NOT `request.user`)
- **Responses**: `new Response(JSON.stringify({...}), { headers: {...} })` (NOT a `json()` helper)
- **Handlers**: Standalone async functions (NOT class methods)
- **Handler signature**: `async function handle*(request, authService, db, env, corsHeaders)`
- **Read the actual `worker/index.js` and `worker/src/auth.js` to match existing patterns exactly.**

**Add 7 new endpoint handlers** (follow existing patterns for request validation, error handling, and response format):

#### 1. `POST /api/auth/set-passcode`
- **Auth required**: Yes (JWT)
- **Body**: `{ passcode: "123456" }`
- **Validation**: Must be exactly 6 digits, user must NOT already have a passcode (use change-passcode for that)
- **Logic**: Generate random salt → SHA-256 hash(passcode + salt) → store in DB
- **Response**: `{ success: true, data: { message: "Passcode set successfully" } }`

```javascript
async handleSetPasscode(request, env) {
    const user = request.user; // From auth middleware
    const { passcode } = await request.json();

    // Validate
    if (!passcode || !/^\d{6}$/.test(passcode)) {
        return json({ success: false, error: 'Passcode must be exactly 6 digits' }, 400);
    }

    // Check if already has passcode
    const existing = await this.db.getUserPasscode(user.id);
    if (existing && existing.passcode_hash) {
        return json({ success: false, error: 'Passcode already set. Use change-passcode endpoint.' }, 400);
    }

    // Hash and store
    const salt = crypto.randomUUID();
    const hash = await this.hashPasscode(passcode, salt);
    await this.db.setUserPasscode(user.id, hash, salt);
    // Also enable passcode by default when first set
    await this.db.prepare(
        'UPDATE users SET passcode_enabled = 1, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).bind(user.id).run();

    return json({ success: true, data: { message: 'Passcode set successfully' } });
}
```

#### 2. `POST /api/auth/verify-passcode`
- **Auth required**: Yes (JWT)
- **Body**: `{ passcode: "123456" }`
- **Logic**: Get stored hash + salt → hash input → compare
- **Response**: `{ success: true, data: { valid: true, passcodeHash: "...", passcodeSalt: "..." } }`
- **Note**: Returns hash + salt on success so iOS can cache locally for offline verification

```javascript
async handleVerifyPasscode(request, env) {
    const user = request.user;
    const { passcode } = await request.json();

    if (!passcode || !/^\d{6}$/.test(passcode)) {
        return json({ success: false, error: 'Passcode must be exactly 6 digits' }, 400);
    }

    const stored = await this.db.getUserPasscode(user.id);
    if (!stored || !stored.passcode_hash) {
        return json({ success: false, error: 'No passcode set' }, 400);
    }

    const hash = await this.hashPasscode(passcode, stored.passcode_salt);
    const valid = hash === stored.passcode_hash;

    if (valid) {
        return json({
            success: true,
            data: {
                valid: true,
                passcodeHash: stored.passcode_hash,
                passcodeSalt: stored.passcode_salt
            }
        });
    } else {
        return json({ success: true, data: { valid: false } });
    }
}
```

#### 3. `POST /api/auth/change-passcode`
- **Auth required**: Yes (JWT)
- **Body**: `{ currentPasscode: "123456", newPasscode: "654321" }`
- **Logic**: Verify current → hash new → update DB
- **Response**: `{ success: true, data: { message: "Passcode changed", passcodeHash: "...", passcodeSalt: "..." } }`

#### 4. `POST /api/auth/reset-passcode-request`
- **Auth required**: Yes (JWT) — user is logged in but locked out
- **Body**: `{}` (uses authenticated user's email)
- **Logic**: Generate token → store with 15-min expiry → send email with 6-digit code
- **Response**: `{ success: true, data: { message: "Reset code sent to your email" } }`

#### 5. `POST /api/auth/reset-passcode`
- **Auth required**: Yes (JWT)
- **Body**: `{ code: "123456", newPasscode: "654321" }` (code is the 6-digit numeric code from email)
- **Logic**: Verify reset token → hash new passcode → update DB → clear reset token
- **Response**: `{ success: true, data: { message: "Passcode reset successfully", passcodeHash: "...", passcodeSalt: "..." } }`

#### 6. `PUT /api/auth/toggle-passcode-enabled`
- **Auth required**: Yes (JWT)
- **Body**: `{ enabled: true }` or `{ enabled: false }`
- **Validation**: User must have a passcode set to enable. Can always disable.
- **Logic**: Update `passcode_enabled` column (1 or 0)
- **Response**: `{ success: true, data: { passcodeEnabled: true } }`

#### 7. `PUT /api/user/passcode-timeout`
- **Auth required**: Yes (JWT)
- **Body**: `{ minutes: 30 }`
- **Validation**: Must be between 1 and 1440 (24 hours)
- **Logic**: Update `passcode_timeout_minutes` column
- **Response**: `{ success: true, data: { passcodeTimeoutMinutes: 30 } }`

**Helper method:**
```javascript
async hashPasscode(passcode, salt) {
    const encoder = new TextEncoder();
    const data = encoder.encode(passcode + salt);
    const hashBuffer = await crypto.subtle.digest('SHA-256', data);
    return Array.from(new Uint8Array(hashBuffer))
        .map(b => b.toString(16).padStart(2, '0'))
        .join('');
}
```

### `worker/src/email.js`

**Add passcode reset email template.** Follow the existing pattern from `sendMagicLink()`:
- Generate a 6-digit numeric code: `Math.floor(100000 + Math.random() * 900000).toString()`
- Use `sendTransactionalEmail()` helper (see `./email-provider.js`)
- Use a template builder function (see `./email-templates.js` patterns)
- Tag: `'passcode_reset'`

```javascript
// Logic (adapt to match existing EmailService class pattern):
async sendPasscodeResetEmail(email, firstName, companyId) {
    const resetCode = Math.floor(100000 + Math.random() * 900000).toString();
    const expiresAt = new Date(Date.now() + 15 * 60 * 1000);

    const subject = 'Reset Your Repair Minder Passcode';
    const html = `
        <h2>Passcode Reset</h2>
        <p>Hi ${firstName || 'there'},</p>
        <p>Your passcode reset code is:</p>
        <h1 style="letter-spacing: 8px; font-size: 32px; text-align: center;">${resetCode}</h1>
        <p>This code expires in 15 minutes.</p>
        <p>If you didn't request this, you can safely ignore this email.</p>
    `;

    // Use sendTransactionalEmail() per existing pattern
    await sendTransactionalEmail({
        to: email,
        from: 'Repair Minder App <app@app.repairminder.com>',
        subject,
        htmlBody: html,
        textBody: this.stripHtml(html),
        tag: 'passcode_reset',
        metadata: { email_type: 'passcode_reset', company_id: companyId }
    }, this.env);

    return { resetCode, expiresAt };
}
```

### `worker/index.js`

**Register new routes.** ⚠️ The codebase uses inline URL pattern matching in the main `fetch` handler — NOT `router.post()`. Read `worker/index.js` to see how existing `/api/auth/*` routes are matched, and add passcode routes following the same pattern.

**Routes to add (all require auth via `checkAuthorization`):**
```
POST /api/auth/set-passcode        → handleSetPasscode
POST /api/auth/verify-passcode     → handleVerifyPasscode
POST /api/auth/change-passcode     → handleChangePasscode
POST /api/auth/reset-passcode-request → handleResetPasscodeRequest
POST /api/auth/reset-passcode      → handleResetPasscode
PUT  /api/auth/toggle-passcode-enabled → handleTogglePasscodeEnabled
PUT  /api/user/passcode-timeout    → handleUpdatePasscodeTimeout
```

### Modify `/api/auth/me` response

**Add `hasPasscode` field** to the existing `GetCurrentUser` handler:

```javascript
// In the /api/auth/me handler, add:
const hasPasscode = !!(user.passcode_hash);

return json({
    success: true,
    data: {
        user: sanitizedUser,
        company: company,
        hasPassword: !!(user.password),
        hasPasscode: !!(user.passcode_hash),
        passcodeEnabled: !!(user.passcode_enabled),
        passcodeTimeoutMinutes: user.passcode_timeout_minutes ?? 15
    }
});
```

### Database helper: `passcode_enabled` toggle

**Add to `worker/src/database.js`:**

```javascript
async togglePasscodeEnabled(userId, enabled) {
    return await this.db.prepare(
        'UPDATE users SET passcode_enabled = ?, updated_at = CURRENT_TIMESTAMP WHERE id = ?'
    ).bind(enabled ? 1 : 0, userId).run();
}
```

---

## Database Changes

| Column | Type | Default | Notes |
|--------|------|---------|-------|
| `passcode_hash` | TEXT | NULL | SHA-256 hash of passcode + salt |
| `passcode_salt` | TEXT | NULL | Random UUID salt |
| `passcode_enabled` | INTEGER | 0 | Whether lock is active (user can disable without deleting passcode) |
| `passcode_timeout_minutes` | INTEGER | 15 | Lock timeout in minutes |
| `passcode_reset_token` | TEXT | NULL | 6-digit reset code |
| `passcode_reset_expires` | DATETIME | NULL | Token expiry |

---

## Test Cases

| # | Scenario | Endpoint | Expected |
|---|----------|----------|----------|
| 1 | Set passcode (first time) | POST /api/auth/set-passcode `{"passcode":"123456"}` | 200, success |
| 2 | Set passcode (already set) | POST /api/auth/set-passcode | 400, "already set" |
| 3 | Set passcode (invalid — 4 digits) | POST /api/auth/set-passcode `{"passcode":"1234"}` | 400, validation error |
| 4 | Set passcode (invalid — letters) | POST /api/auth/set-passcode `{"passcode":"abcdef"}` | 400, validation error |
| 5 | Verify correct passcode | POST /api/auth/verify-passcode `{"passcode":"123456"}` | 200, `valid: true` + hash/salt |
| 6 | Verify wrong passcode | POST /api/auth/verify-passcode `{"passcode":"000000"}` | 200, `valid: false` |
| 7 | Verify no passcode set | POST /api/auth/verify-passcode | 400, "no passcode set" |
| 8 | Change passcode (correct current) | POST /api/auth/change-passcode | 200, new hash/salt returned |
| 9 | Change passcode (wrong current) | POST /api/auth/change-passcode | 400, invalid current |
| 10 | Request reset | POST /api/auth/reset-passcode-request | 200, email sent |
| 11 | Reset with valid code | POST /api/auth/reset-passcode | 200, passcode updated |
| 12 | Reset with expired code | POST /api/auth/reset-passcode | 400, expired |
| 13 | /api/auth/me includes passcode fields | GET /api/auth/me | `hasPasscode`, `passcodeEnabled`, `passcodeTimeoutMinutes` in response |
| 14 | Set timeout | PUT /api/user/passcode-timeout `{"minutes":30}` | 200, updated |
| 15 | Toggle enabled ON | PUT /api/auth/toggle-passcode-enabled `{"enabled":true}` | 200, `passcodeEnabled: true` |
| 16 | Toggle enabled OFF | PUT /api/auth/toggle-passcode-enabled `{"enabled":false}` | 200, `passcodeEnabled: false` |
| 17 | Toggle enabled without passcode | PUT /api/auth/toggle-passcode-enabled `{"enabled":true}` (no hash) | 400, "Set passcode first" |
| 18 | Unauthenticated request | POST /api/auth/set-passcode (no token) | 401 |

---

## Acceptance Checklist

- [ ] Migration `0268` runs successfully on D1
- [ ] `POST /api/auth/set-passcode` creates passcode (hash + salt)
- [ ] `POST /api/auth/verify-passcode` correctly validates passcodes
- [ ] `POST /api/auth/change-passcode` verifies current and sets new
- [ ] `POST /api/auth/reset-passcode-request` sends email with code
- [ ] `POST /api/auth/reset-passcode` resets with valid code
- [ ] `GET /api/auth/me` includes `hasPasscode`, `passcodeEnabled`, and `passcodeTimeoutMinutes`
- [ ] `PUT /api/user/passcode-timeout` updates timeout setting
- [ ] `PUT /api/auth/toggle-passcode-enabled` toggles passcode lock on/off
- [ ] Setting passcode also sets `passcode_enabled = 1`
- [ ] Passcode stored as SHA-256 hash (never plain text)
- [ ] All endpoints require authentication
- [ ] Input validation on all endpoints (6 digits only)
- [ ] Email template renders correctly

---

## Deployment

```bash
# Run migration
cd "/Volumes/Riki Repos/repairminder"
npx wrangler d1 migrations apply repairminder_database --remote

# Deploy worker
npx wrangler deploy worker/index.js

# Test endpoints
curl -X POST https://api.repairminder.com/api/auth/set-passcode \
  -H "Authorization: Bearer <token>" \
  -H "Content-Type: application/json" \
  -d '{"passcode":"123456"}'
```

---

## Handoff Notes

- `/api/auth/me` now returns `hasPasscode: Bool`, `passcodeEnabled: Bool`, and `passcodeTimeoutMinutes: Int` — iOS uses these in [See: Stage 02]
- `/api/auth/verify-passcode` returns `passcodeHash` and `passcodeSalt` on success — iOS caches these locally for offline verification in [See: Stage 02]
- `/api/auth/change-passcode` and reset endpoints return updated hash/salt for cache update
- All endpoints require JWT auth — the user must be logged in (magic link / 2FA) before any passcode operations
