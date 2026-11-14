# Chat 01 final safeguards

- `user_id` immutable through BEFORE UPDATE triggers on profiles, private profile, privacy settings, discovery settings, user interests and user topics. Accounts `id` is its primary key and is not updateable by ordinary clients (no grants).
- All eligibility mutations obtain the same account row lock, with deterministic UUID ordering when multiple accounts are affected. Two-session test explicitly checks expected transaction results, timeouts/deadlocks and final counts (three interests, one topic).
- Existing reactivation rule uses prior `onboarded_at` to avoid rechecking `registration_enabled` for an established account, while continuing data-completeness checks.
- Note: actual PostgreSQL execution, privileged-role and transaction tests remain REQUIRED. Source inspection is not runtime proof.
