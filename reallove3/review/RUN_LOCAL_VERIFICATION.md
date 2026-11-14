# Local verification (never connect to V1 or a hosted project)

Requirements: Docker, Supabase CLI, `psql`, Node/npm. Run on a **disposable local Supabase instance**.

```sh
supabase --version
supabase --help
supabase start
supabase status
supabase db reset --local
# Set LOCAL_DATABASE_URL to the local PostgreSQL URI shown by `supabase status`
psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -f review/VERIFY_LOCAL_DB.sql
psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -f review/TEST_ACTIVATION_AND_RLS.sql
npm install --package-lock-only
npm ci
npm test
npm run typecheck
npm run lint
npm run build
```

**Expected**: migration applies; role test script prints `PASS` and rolls back. If any command fails, retain exact stdout/stderr and do not report approval. `LOCAL_DATABASE_URL` must point to 127.0.0.1 or localhost, not a hosted endpoint. Test fixtures use three artificial `auth.users` entries, all rolled back.

**Limitations**: No application-level user permissions are granted yet, so role tests confirm strict default-deny, not final functional authorized-user flows. Activation uses a trusted administrator function; client access remains forbidden. Test state changes and row visibility with actual account-specific API access when policies are introduced and approved.

## Concurrency and reactivation checks

In a **fresh, disposable** local database after migrations, run:

```sh
psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -f review/TEST_ACTIVATION_AND_RLS.sql
bash review/RUN_CONCURRENCY_TEST.sh
```

`RUN_CONCURRENCY_TEST.sh` starts separate psql sessions and verifies the second of two competing final-selection removals is rejected. It also prints actual remaining counts. The test creates and deletes disposable user fixtures; never run against production. No runtime results have yet been obtained.
