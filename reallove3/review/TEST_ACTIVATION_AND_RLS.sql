-- Execute ONLY on a disposable fresh local Supabase database after migrations.
-- psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -f review/TEST_ACTIVATION_AND_RLS.sql
-- The entire fixture/test session rolls back. Requires postgres admin connection.
\set ON_ERROR_STOP on
begin;
set local statement_timeout = '20s';

-- Auth rows exercise the real auth.users -> private account bootstrap trigger.
insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values
 ('00000000-0000-0000-0000-000000000000','a1000000-0000-4000-8000-000000000001','authenticated','authenticated','v2-a@localhost.test','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','b2000000-0000-4000-8000-000000000002','authenticated','authenticated','v2-b@localhost.test','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','c3000000-0000-4000-8000-000000000003','authenticated','authenticated','v2-restricted@localhost.test','',now(),now(),now());

do $$ begin
 if (select count(*) from app_private.accounts where id in
 ('a1000000-0000-4000-8000-000000000001','b2000000-0000-4000-8000-000000000002','c3000000-0000-4000-8000-000000000003') and status='onboarding') <> 3
 then raise exception 'FAIL: trusted account bootstrap'; end if;
end $$;

insert into public.country_eligibility(country_code,registration_enabled,discovery_enabled)
values ('US', true, true), ('CA', false, true);
insert into public.general_locations(country_code,region,locality,reference_latitude,reference_longitude,resolution_status)
values ('US','TX','Austin',30.267,-97.743,'resolved'),('CA','ON','Toronto',43.653,-79.383,'resolved'),('US','TX','Unknown',null,null,'unresolved');
insert into public.interests(slug,label) values ('music','Music'),('philosophy','Philosophy'),('science','Science');
insert into public.topics(slug,label) values ('ethics','Ethics');

insert into public.profiles(user_id,display_name,location_id)
values ('a1000000-0000-4000-8000-000000000001','User A',(select id from public.general_locations where locality='Austin'));
insert into app_private.profile_private(user_id,date_of_birth) values ('a1000000-0000-4000-8000-000000000001',current_date - interval '17 years');
insert into public.user_interests(user_id,interest_id)
select 'a1000000-0000-4000-8000-000000000001',id from public.interests;
insert into public.user_topics(user_id,topic_id)
select 'a1000000-0000-4000-8000-000000000001',id from public.topics;

-- Negative: underage activation, despite otherwise complete profile.
do $$ begin
 begin
  perform app_private.complete_onboarding('a1000000-0000-4000-8000-000000000001');
  raise exception 'FAIL: underage activation accepted';
 exception when others then
  if sqlerrm = 'FAIL: underage activation accepted' then raise; end if;
  if position('at least 18' in sqlerrm)=0 then raise; end if;
 end;
end $$;

update app_private.profile_private set date_of_birth=current_date - interval '20 years' where user_id='a1000000-0000-4000-8000-000000000001';
-- Missing profile/location/interests/topics: User B is initially incomplete.
do $$ begin
 begin
  perform app_private.complete_onboarding('b2000000-0000-4000-8000-000000000002');
  raise exception 'FAIL: incomplete onboarding accepted';
 exception when others then
  if sqlerrm = 'FAIL: incomplete onboarding accepted' then raise; end if;
  if position('Valid profile' in sqlerrm)=0 then raise; end if;
 end;
end $$;

-- Negative: no registration eligibility in CA.
insert into public.profiles(user_id,display_name,location_id)
values ('b2000000-0000-4000-8000-000000000002','User B',(select id from public.general_locations where locality='Toronto'));
insert into app_private.profile_private(user_id,date_of_birth) values ('b2000000-0000-4000-8000-000000000002',current_date - interval '20 years');
insert into public.user_interests(user_id,interest_id) select 'b2000000-0000-4000-8000-000000000002',id from public.interests;
insert into public.user_topics(user_id,topic_id) select 'b2000000-0000-4000-8000-000000000002',id from public.topics;
do $$ begin
 begin
  perform app_private.complete_onboarding('b2000000-0000-4000-8000-000000000002');
  raise exception 'FAIL: disabled-country activation accepted';
 exception when others then
  if sqlerrm = 'FAIL: disabled-country activation accepted' then raise; end if;
  if position('not eligible' in sqlerrm)=0 then raise; end if;
 end;
end $$;

-- Negative: unresolved reference despite a location id.
update public.profiles set location_id=(select id from public.general_locations where locality='Unknown') where user_id='b2000000-0000-4000-8000-000000000002';
do $$ begin
 begin
  perform app_private.complete_onboarding('b2000000-0000-4000-8000-000000000002');
  raise exception 'FAIL: unresolved location accepted';
 exception when others then
  if sqlerrm = 'FAIL: unresolved location accepted' then raise; end if;
  if position('resolved location' in sqlerrm)=0 then raise; end if;
 end;
end $$;

-- Negative: two interests (must have at least three).
delete from public.user_interests where user_id='b2000000-0000-4000-8000-000000000002'
 and interest_id=(select id from public.interests where slug='science');
update public.profiles set location_id=(select id from public.general_locations where locality='Austin')
 where user_id='b2000000-0000-4000-8000-000000000002';
do $$ begin
 begin
  perform app_private.complete_onboarding('b2000000-0000-4000-8000-000000000002');
  raise exception 'FAIL: activation with two interests accepted';
 exception when others then
  if sqlerrm = 'FAIL: activation with two interests accepted' then raise; end if;
  if position('three active interests' in sqlerrm)=0 then raise; end if;
 end;
end $$;
insert into public.user_interests(user_id,interest_id)
select 'b2000000-0000-4000-8000-000000000002',id from public.interests where slug='science';

-- Negative: zero topics.
delete from public.user_topics where user_id='b2000000-0000-4000-8000-000000000002';
do $$ begin
 begin
  perform app_private.complete_onboarding('b2000000-0000-4000-8000-000000000002');
  raise exception 'FAIL: activation with zero topics accepted';
 exception when others then
  if sqlerrm = 'FAIL: activation with zero topics accepted' then raise; end if;
  if position('one active topic' in sqlerrm)=0 then raise; end if;
 end;
end $$;
insert into public.user_topics(user_id,topic_id)
select 'b2000000-0000-4000-8000-000000000002',id from public.topics where slug='ethics';

-- Negative: missing display name; this should be rejected by the table CHECK.
do $$ begin
 begin
  update public.profiles set display_name='' where user_id='b2000000-0000-4000-8000-000000000002';
  raise exception 'FAIL: blank display name accepted';
 exception when check_violation then null;
 end;
end $$;
-- Negative: invalid reference coordinates; this should be rejected by CHECK.
do $$ begin
 begin
  update public.general_locations set reference_latitude=91 where locality='Austin';
  raise exception 'FAIL: invalid latitude accepted';
 exception when check_violation then null;
 end;
end $$;

-- Positive activation and state assertions.
select app_private.complete_onboarding('a1000000-0000-4000-8000-000000000001');
do $$ begin
 if not exists(select 1 from app_private.accounts where id='a1000000-0000-4000-8000-000000000001' and status='active' and onboarded_at is not null)
 then raise exception 'FAIL: successful activation'; end if;
end $$;

-- Negative: post-activation required selections cannot be deleted.
do $$ begin
 begin
  delete from public.user_topics where user_id='a1000000-0000-4000-8000-000000000001';
  raise exception 'FAIL: active topic deletion accepted';
 exception when others then
  if sqlerrm = 'FAIL: active topic deletion accepted' then raise; end if;
  if position('one active topic' in sqlerrm)=0 then raise; end if;
 end;
 begin
  update public.profiles set location_id=null where user_id='a1000000-0000-4000-8000-000000000001';
  raise exception 'FAIL: active location removal accepted';
 exception when others then
  if sqlerrm = 'FAIL: active location removal accepted' then raise; end if;
  if position('resolved location' in sqlerrm)=0 then raise; end if;
 end;
 begin
  update app_private.profile_private set date_of_birth=current_date - interval '17 years' where user_id='a1000000-0000-4000-8000-000000000001';
  raise exception 'FAIL: active underage edit accepted';
 exception when others then
  if sqlerrm = 'FAIL: active underage edit accepted' then raise; end if;
  if position('at least 18' in sqlerrm)=0 then raise; end if;
 end;
end $$;

-- Negative: active user may not drop from three to two interests.
do $$ begin
 begin
  delete from public.user_interests where user_id='a1000000-0000-4000-8000-000000000001'
   and interest_id=(select id from public.interests where slug='science');
  raise exception 'FAIL: active interest deletion accepted';
 exception when others then
  if sqlerrm = 'FAIL: active interest deletion accepted' then raise; end if;
  if position('three active interests' in sqlerrm)=0 then raise; end if;
 end;
end $$;

-- Country changes don't retroactively deactivate existing accounts.
update public.country_eligibility set registration_enabled=false where country_code='US';
do $$ begin
 if (select status from app_private.accounts where id='a1000000-0000-4000-8000-000000000001') <> 'active'
 then raise exception 'FAIL: grandfathered account changed'; end if;
end $$;

-- A previously onboarded restricted account may reactivate even after registration closes.
update app_private.accounts set status='restricted' where id='a1000000-0000-4000-8000-000000000001';
update app_private.accounts set status='active' where id='a1000000-0000-4000-8000-000000000001';
do $$ begin
 if not exists (select 1 from app_private.accounts where id='a1000000-0000-4000-8000-000000000001' and status='active')
 then raise exception 'FAIL: previously onboarded account reactivation'; end if;
end $$;
-- Keep User C restricted for role-denial test.
update app_private.accounts set status='restricted' where id='c3000000-0000-4000-8000-000000000003';

-- Executable role tests. These use actual postgres roles, not commented examples.
set local role anon;
do $$ begin
 begin
  perform 1 from public.profiles limit 1;
  raise exception 'FAIL: anonymous profiles read';
 exception when insufficient_privilege then null;
 end;
 begin
  perform app_private.complete_onboarding('b2000000-0000-4000-8000-000000000002');
  raise exception 'FAIL: anonymous activation';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;

set local role authenticated;
select set_config('request.jwt.claim.sub','a1000000-0000-4000-8000-000000000001',true);
do $$ begin
 begin
  perform 1 from app_private.profile_private where user_id='b2000000-0000-4000-8000-000000000002';
  raise exception 'FAIL: cross-account DOB read';
 exception when insufficient_privilege then null;
 end;
 begin
  update app_private.accounts set status='active' where id='b2000000-0000-4000-8000-000000000002';
  raise exception 'FAIL: client account status update';
 exception when insufficient_privilege then null;
 end;
 begin
  update public.country_eligibility set registration_enabled=true where country_code='CA';
  raise exception 'FAIL: client country admin update';
 exception when insufficient_privilege then null;
 end;
 begin
  perform 1 from app_private.discovery_settings where user_id='b2000000-0000-4000-8000-000000000002';
  raise exception 'FAIL: cross-account settings read';
 exception when insufficient_privilege then null;
 end;
end $$;
-- A restricted user also has no direct privileged data path.
select set_config('request.jwt.claim.sub','c3000000-0000-4000-8000-000000000003',true);
do $$ begin
 begin
  perform 1 from app_private.accounts where id='c3000000-0000-4000-8000-000000000003';
  raise exception 'FAIL: restricted account directly read private account';
 exception when insufficient_privilege then null;
 end;
 begin
  perform app_private.complete_onboarding('c3000000-0000-4000-8000-000000000003');
  raise exception 'FAIL: restricted account activated itself';
 exception when insufficient_privilege then null;
 end;
end $$;
reset role;
rollback;
\echo 'PASS: all checks completed and rolled back (only if no SQL error above)'
