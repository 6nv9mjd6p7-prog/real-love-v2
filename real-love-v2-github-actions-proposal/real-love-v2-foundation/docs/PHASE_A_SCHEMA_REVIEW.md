# Chat 01 correction return — Phase A Step 4

Status: corrected **candidate** migration, not approved or applied.

Corrections: six exact account states; onboarding step/timestamp; 50-mile distance default and an explicit Anywhere switch; 18-to-unbounded (NULL for 100+) discovery preference; friendship intention default; approximate location reference and resolution status; country registration/discovery flags and effective timestamp; accounts and settings moved into app_private; FORCE RLS actually applied on all eleven tables. The existing npm dependency lockfile is still missing because npm access has not succeeded.

Security: all eleven tables have RLS and FORCE RLS, no allow policies, and private schema grants are revoked. This prevents ordinary frontend access until an authorization implementation is reviewed. No production data or credentials were accessed.

Remaining contract issues requiring review: approved representation of location resolution and privacy visibility fields; account activation and 18+ requirements **are not yet database-enforced**; explicit authenticated API read/write policies and country configuration administration are not implemented. No claim of a functional onboarding or country management flow is made.

Runtime: no Docker, psql or Supabase CLI in this environment. No real PostgreSQL execution, RLS cross-user test, migration reset, or authenticated browser test. npm installation/build not verified. Offline static tests are not substitutes for runtime security testing.

Next: review SQL in Chat 01, apply with Supabase CLI to clean local environment, test anon/User A/User B and age/status enforcement before advancing to Auth Step 5.
