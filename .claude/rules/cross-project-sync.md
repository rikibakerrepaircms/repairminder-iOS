# Cross-Project Sync Rule

Repair Minder is a two-project system. Changes to one project often require changes to the other.

## Project Locations

- **iOS app:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS`
- **Web app + API (Cloudflare Workers):** `/Volumes/Riki Repos/repairminder`

## When Making Changes

Before implementing any feature, bug fix, or refactor in the iOS app:

1. **Check the API contract.** If the feature depends on an API endpoint, read the backend route handler in `/Volumes/Riki Repos/repairminder/worker/src/` to confirm the request/response shape. Do not assume — verify.

2. **Flag backend changes needed.** If the iOS work requires a new endpoint, a modified response, or a new field, explicitly call this out before writing any code. The backend change must be planned and agreed upon first.

3. **Match model shapes.** iOS Swift models must match the API response. When the backend adds or changes a field, the corresponding Swift `Codable` model must be updated. Remember: the API uses `snake_case`, the iOS decoder uses `.convertFromSnakeCase`.

4. **Keep demo data in sync.** If adding features that affect demo/seed data (App Store review environment), ensure both the backend seed SQL and any iOS-side demo expectations are aligned.

5. **Document the dependency.** When a task spans both projects, note in the plan which project changes must land first (usually backend before iOS).

## Sync Checklist (ask yourself before completing any task)

- Does this change affect or depend on an API endpoint? → Check backend
- Does this add a new model or field? → Verify it exists in the API response
- Does this change auth flow or user roles? → Both projects must be updated
- Does this affect push notifications? → Check both APNs config and backend triggers
- Does this change the customer portal? → Web and iOS customer views must match
