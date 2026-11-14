# Chat 01 — Step 4 correction return (2026-10-30)

## Modified implementation
- `supabase/migrations/20261030000000_phase_a_foundation.sql`: corrected activation guard, centralized active-profile checks, triggers for critical post-activation mutations (profile, DOB, interests, topics, reference location and catalog activity), trusted account bootstrap on `auth.users`, database-managed updated_at triggers.
- `review/EXACT_PHASE_A_MIGRATION.sql`: exact matching SQL for line review.
- `tests/ongoing-eligibility.test.mjs`: extra offline assertions.
- Existing tests updated to match restructured eligibility function.

## Authorization boundaries
- `app_private.accounts` is created only by an `auth.users` database trigger; clients have no direct grants on `app_private`.
- `app_private.complete_onboarding(uuid)` is SECURITY INVOKER and execution is revoked from PUBLIC, anon, authenticated. Its caller must be a trusted server/database role; no browser service key.
- All 11 tables have RLS ENABLE and FORCE, with no client policies or grants at this stage. This is an intentional **deny-only foundation**, not complete functional CRUD authorization.
- `SECURITY DEFINER` is used only for `auth.users` bootstrap; its schema is not exposed and function EXECUTE is revoked from client roles. Verify actual ownership and grants locally.
- Country registration eligibility applies on entry to active. Subsequent country policy updates do not automatically ban existing users.

## Remaining technical risks / follow-up
- A valid profile with a resolved approximate reference point is required, but the quality of geographic lookup needs later application-side validation and testing.
- Concurrent user selection/catalog mutations require actual PostgreSQL multi-session tests before accepting the ongoing-eligibility guard as complete. Database triggers protect ordinary single-transaction writes, but are **not** yet proof of race safety.
- The account creation path is an auth trigger, not an approved user-editable client API. The authorized onboarding write API remains unimplemented (gated).
- PostgreSQL execution, role-impersonation tests, a fresh Supabase reset, npm lockfile, TypeScript/lint/build and browser tests were **not executed** here.

## Executed tests
`node --test tests/*.test.mjs`: **20 passed, 0 failed**. Source-level tests only.

## Local tests required before approval
Use `review/RUN_LOCAL_VERIFICATION.md`, execute `supabase db reset --local` and `psql "$LOCAL_DATABASE_URL" -v ON_ERROR_STOP=1 -f review/VERIFY_LOCAL_DB.sql`, then test separate auth identities, role grants, activation failures, protected updates, and concurrent access. Record output. No hosted project, no V1 credentials.
