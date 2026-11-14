-- Run AFTER 'supabase db reset' against local-only DB, with postgres admin connection.
-- Source-level checks are not equivalent to executing these assertions.
DO $$
DECLARE n int;
BEGIN
 SELECT count(*) INTO n FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
 WHERE c.relkind='r' AND ns.nspname IN ('public','app_private')
 AND c.relname = ANY(ARRAY['accounts','profiles','profile_private','general_locations','privacy_settings','discovery_settings','interests','topics','user_interests','user_topics','country_eligibility']);
 IF n <> 11 THEN RAISE EXCEPTION 'Expected 11 Phase A tables, found %',n; END IF;
 IF EXISTS (
  SELECT 1 FROM pg_class c JOIN pg_namespace ns ON ns.oid=c.relnamespace
  WHERE c.relkind='r' AND ns.nspname IN ('public','app_private')
  AND c.relname = ANY(ARRAY['accounts','profiles','profile_private','general_locations','privacy_settings','discovery_settings','interests','topics','user_interests','user_topics','country_eligibility'])
  AND (NOT c.relrowsecurity OR NOT c.relforcerowsecurity)
 ) THEN RAISE EXCEPTION 'Some Phase A tables lack ENABLE+FORCE RLS'; END IF;
 IF has_schema_privilege('authenticated','app_private','USAGE') OR has_schema_privilege('anon','app_private','USAGE')
 THEN RAISE EXCEPTION 'Private schema accessible to clients'; END IF;
 IF has_table_privilege('authenticated','app_private.accounts','UPDATE')
 THEN RAISE EXCEPTION 'Client can update accounts'; END IF;
 IF has_function_privilege('authenticated','app_private.complete_onboarding(uuid)','EXECUTE')
 THEN RAISE EXCEPTION 'Client can activate account'; END IF;
 IF NOT EXISTS (
  SELECT 1 FROM pg_constraint co JOIN pg_class c ON c.oid=co.conrelid
  JOIN pg_namespace n ON n.oid=c.relnamespace
  WHERE n.nspname='app_private' AND c.relname='accounts' AND co.contype='f'
  AND co.confrelid='auth.users'::regclass
 ) THEN RAISE EXCEPTION 'Missing auth.users FK'; END IF;
 RAISE NOTICE 'Phase A schema/RLS/grants assertions passed';
END $$;
-- These should fail with permission denied; run in separate transactions.
-- SET ROLE anon; SELECT * FROM app_private.profile_private; RESET ROLE;
-- SET ROLE authenticated; SELECT * FROM app_private.discovery_settings; RESET ROLE;
-- SET ROLE authenticated; SELECT * FROM public.profiles; RESET ROLE;
-- Full User A/User B tests require seeded local auth identities plus approved read/write policies.
