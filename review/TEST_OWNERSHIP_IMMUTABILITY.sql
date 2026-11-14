-- Executable ownership integrity check: run on fresh disposable local Supabase.
-- Inserts disposable Auth users, attempts 7 forbidden ownership changes,
-- verifies originals remain intact and rolls back every fixture.
\set ON_ERROR_STOP on
begin;
set local statement_timeout = '20s';

insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values
 ('00000000-0000-0000-0000-000000000000','f1000000-0000-4000-8000-000000000001','authenticated','authenticated','ownership-a@localhost.test','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','f2000000-0000-4000-8000-000000000002','authenticated','authenticated','ownership-b@localhost.test','',now(),now(),now());

insert into public.profiles(user_id,display_name) values ('f1000000-0000-4000-8000-000000000001','Owner A');
insert into app_private.profile_private(user_id,date_of_birth) values ('f1000000-0000-4000-8000-000000000001',date '2000-01-01');
insert into app_private.privacy_settings(user_id) values ('f1000000-0000-4000-8000-000000000001');
insert into app_private.discovery_settings(user_id) values ('f1000000-0000-4000-8000-000000000001');
insert into public.interests(slug,label) values ('ownership-test-interest','Ownership Test Interest');
insert into public.topics(slug,label) values ('ownership-test-topic','Ownership Test Topic');
insert into public.user_interests(user_id,interest_id)
select 'f1000000-0000-4000-8000-000000000001',id from public.interests where slug='ownership-test-interest';
insert into public.user_topics(user_id,topic_id)
select 'f1000000-0000-4000-8000-000000000001',id from public.topics where slug='ownership-test-topic';

do $$
declare t text;
        tables text[] := array[
          'public.profiles','app_private.profile_private',
          'app_private.privacy_settings','app_private.discovery_settings',
          'public.user_interests','public.user_topics'
        ];
        rejected boolean;
begin
  foreach t in array tables loop
    rejected := false;
    begin
      execute format('update %s set user_id=$1 where user_id=$2',t)
        using 'f2000000-0000-4000-8000-000000000002'::uuid,
              'f1000000-0000-4000-8000-000000000001'::uuid;
    exception when check_violation then
      if sqlerrm <> 'user_id is immutable' then raise; end if;
      rejected := true;
    end;
    if not rejected then raise exception 'FAIL: ownership reassignment accepted on %',t; end if;
    execute format('select 1 from %s where user_id=$1',t)
      using 'f1000000-0000-4000-8000-000000000001'::uuid;
    if not found then raise exception 'FAIL: owner record lost on %',t; end if;
    execute format('select 1 from %s where user_id=$1',t)
      using 'f2000000-0000-4000-8000-000000000002'::uuid;
    if found then raise exception 'FAIL: unauthorized owner row created on %',t; end if;
    raise notice 'PASS: % owner immutable',t;
  end loop;
  rejected := false;
  begin
    update app_private.accounts
       set id='f2000000-0000-4000-8000-000000000002'
     where id='f1000000-0000-4000-8000-000000000001';
  exception when check_violation then
    if sqlerrm <> 'account id is immutable' then raise; end if;
    rejected := true;
  end;
  if not rejected then raise exception 'FAIL: account id reassignment accepted'; end if;
  if not exists(select 1 from app_private.accounts where id='f1000000-0000-4000-8000-000000000001')
    or (select count(*) from app_private.accounts where id='f2000000-0000-4000-8000-000000000002') <> 1
  then raise exception 'FAIL: account ownership changed'; end if;
  raise notice 'PASS: account ID immutable; 7/7 owner identity checks passed';
end $$;

rollback;
\echo 'PASS: ownership test assertions completed (fixtures rolled back)'
