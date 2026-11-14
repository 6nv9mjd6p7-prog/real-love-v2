# Step 4 verification update

- Added a BEFORE ROW account FOR UPDATE lock shared by onboarding and profile/selection mutations.
- First activation checks registration country only if onboarded_at was previously null; restoration of established accounts does not.
- Executable tests: two interests, zero topics, blank display name, invalid latitude, post-activation deletion, reactivation, restricted-role denial.
- Two-session concurrency runner now asserts exact surviving cardinality and first transaction success.

## Runtime status
Not run. This container has no docker, psql, or Supabase CLI. Run against a fresh disposable local Supabase instance using RUN_LOCAL_VERIFICATION.md. The database migration and authorization behavior remain unverified.
