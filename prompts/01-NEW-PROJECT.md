# RepairMinder iOS - New Project Prompt

You are a technical project manager. Your task has two parts, with a GATE between them.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-native-app/00-master-plan.md`
**Test Tokens & API Reference:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/docs/REFERENCE-test-tokens/CLAUDE.md`
**Xcode Project:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/Repair Minder/`

---

## Part 1: Review the Specification

Read the Master Plan and all stage documents (01 through 15).

Review them for:
- **Completeness** - Are requirements clear? Any gaps that would block a developer?
- **Technical accuracy** - Do Swift code snippets look correct? Are SwiftUI patterns modern (iOS 17+)?
- **Stage dependencies** - Is the order logical? Are prerequisites clearly stated?
- **Test coverage** - Do checklists cover acceptance criteria and edge cases?

### If you find issues:

**Fixable issues** (typos, minor code errors, missing details you can infer):
→ Fix them directly in the spec file and note what you changed.

**Blocking issues** (ambiguous requirements, missing context, decisions needed):
→ STOP and list your questions. Do NOT proceed to Part 2.

---

## 🚫 GATE: Do not proceed until the spec is accurate and complete.

---

## Part 2: Create the Stage 1 Worker Prompt

Only proceed here once the specification has no outstanding issues.

Write a clear prompt for a developer to implement **Stage 1: Project Architecture** only.

### The prompt MUST include these sections:

**1. Task Overview**
- Which file(s) to create/modify
- Reference to the stage document: `plans/ios-native-app/01-project-architecture.md`
- Clear objective (folder structure, AppState, AppRouter, shared components)

**2. Scope Boundaries**

SHOULD do:
- Create folder structure (App/, Core/, Features/, Shared/, Resources/)
- Implement AppState.swift, AppRouter.swift, Environment.swift
- Create shared components (LoadingView, ErrorView, EmptyStateView)
- Add extensions (Date+, String+, View+)
- Set up MainTabView with placeholder tabs
- Configure Xcode project settings for iOS 17+

SHOULD NOT do:
- Implement networking (Stage 02)
- Implement authentication (Stage 03)
- Add any API calls
- Create feature-specific views beyond placeholders

**3. Reference Files** ⚠️ REQUIRED
- Direct the worker to check `docs/REFERENCE-test-tokens/CLAUDE.md` for API base URL and test tokens
- The API base URL is `https://api.repairminder.com`
- No authenticated API calls in Stage 1, but familiarise with the token structure

**4. Verification Steps** ⚠️ REQUIRED
- Build the project successfully in Xcode
- Run on iOS 17+ Simulator
- Verify tab navigation works
- Verify placeholder views display correctly
- Check no compiler warnings

**5. Build & Run** ⚠️ REQUIRED
Using XcodeBuildMCP tools:
```
1. mcp__XcodeBuildMCP__session-set-defaults (set project path, scheme, simulator)
2. mcp__XcodeBuildMCP__build_sim (build for simulator)
3. mcp__XcodeBuildMCP__build_run_sim (build and run)
4. mcp__XcodeBuildMCP__screenshot (capture verification screenshot)
```

**6. Completion Checklist**
- [ ] Folder structure created
- [ ] AppState, AppRouter, Environment implemented
- [ ] Shared components created
- [ ] Extensions added
- [ ] MainTabView with tabs working
- [ ] Builds without errors
- [ ] Runs on simulator
- [ ] Screenshot captured showing tab bar

### Format
Output your worker prompt in a code block so it can be copied directly. Keep it brief—the spec documents contain the detail.

---

## Stage Dependency Map (for reference)

```
Sequential (must be in order):
  Stage 01 → 02 → 03 → 04 → 05

After Stage 05, these can run in PARALLEL:
  Batch A: 06, 07, 08, 09, 10 (all feature modules)
  Batch B: 11 (Push Notifications)

After Batch A + B complete:
  Stage 12 (requires 03 + 11)
  Stage 15 (requires 07 + 11)

After all features:
  Stage 13 (Settings & Polish)
  Stage 14 (White-Label)
```
