# Real Love V2 — Phase A Step 4: Schema review return

**Status: NOT APPROVED FOR AUTH IMPLEMENTATION.** This package includes the exact SQL migration and a source-level audit. The migration has not run in PostgreSQL.

## Exact SQL

`EXACT_PHASE_A_MIGRATION.sql` is a byte-for-byte copy of `../supabase/migrations/20261030000000_phase_a_foundation.sql`.

## Tables and constraints

- `app_private.accounts`: `id uuid PK → auth.users(id) CASCADE`; status enumerated CHECK, onboarding step length CHECK, timestamps; default `onboarding`.
- `public.general_locations`: identity PK; country ISO-like two-capitals CHECK; restricted three-decimal reference lat/lon with range, paired/non-null and resolution checks; nulls-not-distinct unique (country, region, locality).
- `public.profiles`: `user_id PK → accounts CASCADE`; display name 1–80 chars CHECK; bio ≤1000; FK to general_locations; discoverable false.
- `app_private.profile_private`: `user_id PK → accounts CASCADE`; DOB required.
- `app_private.privacy_settings`: `user_id PK → accounts CASCADE`.
- `app_private.discovery_settings`: `user_id PK → accounts CASCADE`; radius 10/25/50/100 CHECK default 50, explicit anywhere false, friendship intention, minimum age 18–100 CHECK, maximum age 18–100 or null (null = 100+), ordered range CHECK.
- `public.interests`: identity PK; unique slug and label; slug pattern CHECK; active true.
- `public.topics`: identity PK; unique slug and label; slug pattern CHECK; active true.
- `public.user_interests`: composite PK(user_id, interest_id); FKs accounts CASCADE and interests.
- `public.user_topics`: composite PK(user_id, topic_id); FKs accounts CASCADE and topics.
- `public.country_eligibility`: country code PK/check; separate registration_enabled and discovery_enabled defaults false; effective and updated timestamps.

## Security configuration

All 11 tables have ENABLE and FORCE RLS. There are **no allow policies**; all public tables have explicit REVOKE from public, anon, authenticated, and the private schema and its objects are revoked from the same. `app_private` is not an exposed API schema in local configuration. This is a locked baseline; *not* a functioning authorization design.

A `BEFORE INSERT OR UPDATE OF status, onboarded_at` trigger on `app_private.accounts` checks activation: at least 18 at activation, three currently active interests, one currently active topic, an eligible registration country (effective_at <= now()), and onboarded_at present. IMPORTANT: this only guards transitions; changes/deletion of dependencies **after activation** and the approval process for country configuration need a separate authorization/consistency decision. It also does not establish mutual discovery eligibility or location privacy controls.

## Critical deviations and unverified items

1. `app_private.accounts` uses `id`, not the contract's explicit `accounts.user_id` naming. The FK `id → auth.users(id)` is present; ask Chat 01 to confirm naming, or rename column before approval.
2. General locations are in `public` and `profiles.location_id` exists; although direct access is denied, per-user general location visibility semantics are not implemented. `profile_private` contains DOB only. Exact field visibility still needs review.
3. Privacy settings table has no visibility fields. It is a placeholder, not a full privacy contract.
4. `maximum_age = NULL` represents 100+, while setting 100 as an upper limit excludes ages 101+; ensure approved UX maps 100+ to NULL.
5. No read/write policies or admin-only country-configuration functions exist. Country flags are database-configurable by privileged manual SQL only.
6. No actual database-role test (anon/A/B/restricted), PostgreSQL migration or local Supabase reset performed.
7. No dependency lockfile, installation, build, or integration verification completed.
8. The full Database & Authorization Contract V1.0 was not present in the accessible files; this cannot certify field-by-field compliance.

## Runtime blocker

Environment has Node.js 22 and offline tests, but no `docker`, `podman`, `psql`, `postgres`, `pg_ctl` or `supabase` executable. PostgreSQL cannot be started here. A clean local Supabase startup, migration application, checks against `pg_catalog`, role simulation, and API tests **remain mandatory before Step 5**.

## Results

`node --test tests/*.test.mjs`: 14/14 passed, **source inspections only**. Runtime DB tests: 0 executed.

No V1 data, production database, or hosted Supabase project touched. No deployment. Cost $0.
