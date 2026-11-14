# Chat 01 approval request — alternate runtime environment

The V2 Phase A database contract originally required developer-machine local Supabase PostgreSQL. This proposal runs the same local Supabase containers on an **ephemeral GitHub-hosted Ubuntu runner** using Docker, with no linked Supabase Cloud project. It changes the execution location, not the database schema or product scope.

Approval granted by Chat 01: the manually dispatched GitHub-hosted temporary runner is authorized for test execution. GitHub Actions standard runners are included without charge for public repositories (subject to usage and policy). No production or V1 repository changes are authorized.

## How to use after approval

1. Create a **separate** `real-love-v2` GitHub repository; do not push to or modify `real-love` V1. Keep this repository public only if comfortable with the migration and test code being public. A private repo may consume included Actions minutes and can incur charges beyond allowances; review billing first.
2. Extract this project archive and upload its `real-love-v2-foundation/` contents to the root of the new repository, including `.github/workflows/phase-a-step4-runtime.yml` and `supabase/migrations/...`.
3. GitHub > real-love-v2 > Actions > `Real Love V2 — Phase A Step 4 runtime verification` > Run workflow.
4. Wait for the job result. Under its Summary, download artifact `real-love-v2-phase-a-step4-evidence`. Provide both run URL and the logs for Chat 03 / Chat 01.
5. Do NOT run a production deployment workflow or `supabase link`, `db push --remote`, or `db reset --remote`.

The workflow uses `workflow_dispatch` ONLY; it won't start on every push. It uses `supabase start`, `supabase db reset --local --no-seed`, and the versioned SQL migration in the isolated repository. It calls the existing activation/RLS tests and actual two-session concurrency script, and records versions and application build output. A failed step stops later steps and still uploads available logs. Test failures are **not** evidence of success.

## Current verification status

Workflow file: created and YAML-syntax checked offline. GitHub Actions execution: NOT RUN. PostgreSQL migration: NOT RUN. Runtime assertions: NOT RUN. App build: NOT RUN. No guarantee the workflow passes; first execution may expose SQL defects requiring correction. Dependency installation generates package-lock.json on the runner; it must later be committed to the V2 repository for a frozen install.

## Security and completeness notes

The existing role SQL tests check default-deny access and privileged behavior, not working authorized user data APIs. They do not demonstrate all eventual Phase A authorization behavior. Confirm coverage in logs and request any missing integration cases from Chat 01. The proposed workflow uses tagged GitHub Actions and `latest` Supabase CLI for ease of initial setup; for production-grade repeatability, pin audited action commit SHAs and a confirmed Supabase CLI version after the first successful isolated run.

## Approval and corrections (November 14, 2026)

Chat 01 approved ephemeral GitHub Actions verification. The workflow now hides Supabase startup output so local database passwords and API tokens are not captured in run artifacts. It generates a `package-lock.json` in the runner, then verifies installation with `npm ci`. Download and commit the generated lockfile to V2 after reviewing it; the workflow cannot commit it with read-only permissions. The secondary foundation CI is manual-only until the lockfile is committed.

**IMPORTANT:** The connected GitHub integration in this session cannot create a new repository. Create a blank `real-love-v2` repository via GitHub's new-repository page, do not initialize it with a README, then upload the package contents. No V1 modifications are authorized.
