# CHECKING WORK

You are a technical project manager reviewing completed work.

---

## CONFIGURATION

**Master Plan Path:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-booking-aftermarket-consent/00-master-plan.md`
**Stage Documents:** `/Volumes/Riki Repos/repairminder-iOS/repairminder-iOS/plans/ios-booking-aftermarket-consent/`
**Just Completed:** Stage X (FILL IN)

---

## Part 1: Review the Completed Stage

Read the stage document for the just-completed stage and verify it was implemented correctly:

### Code Review
- Were the correct files created/modified?
- Does the implementation match the spec?
- Any obvious bugs, edge cases missed, or code quality issues?

### Build Verification
- Do all 3 targets build clean? (iOS, iPad, Mac)
- Use Xcode MCP tool or `xcodebuild` to verify compilation

### Test Coverage
- Were the acceptance criteria in the checklist met?
- Are there things I should manually test/verify? List specific steps.

### If you find issues:

**Fixable issues** (minor bugs, missing error handling you can add):
→ Fix them and note what you changed.

**Blocking issues** (broken functionality, spec deviation, build failure):
→ STOP and tell me what's wrong. Do NOT proceed to the next stage.

---

## 🚫 GATE: Do not proceed until the completed stage fully works.

---

## Part 2: Update Progress

Mark the completed stage as done in the Master Plan (add ✅ to the stage heading in the Stage Index).

---

## Part 3: Parallel Stage Analysis

Before creating the next prompt, check the dependency graph:
- Stages 1 + 5 can run in parallel (Stage 5 only depends on Stage 1)
- Stages 2 → 3 → 4 are strictly sequential
- If Stage 1 just completed, generate prompts for BOTH Stage 2 AND Stage 5

---

## Part 4: Create the Next Stage Worker Prompt(s)

Generate the prompt for the next stage(s) using the same format:

1. **Task Overview** (files, functions, spec sections)
2. **Scope Boundaries** (do / don't do)
3. **Reference Files** — point to the stage document for detailed implementation specs. Reference the backend code at `/Volumes/Riki Repos/repairminder/worker/` if the worker needs to verify API response shapes.
4. **Verification Steps** (build all 3 targets, specific UI tests)
5. **Completion Checklist**

Output each worker prompt in its own code block. If multiple stages can run in parallel, output them as separate code blocks labelled "PARALLEL STAGE X" and "PARALLEL STAGE Y".

If there is no next stage, confirm the project is complete and summarise what was built.
