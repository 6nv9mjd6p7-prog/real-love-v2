\set ON_ERROR_STOP on
-- Disposable local DB only. Prepares two complete accounts with one spare selection.
insert into auth.users (instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,created_at,updated_at)
values
 ('00000000-0000-0000-0000-000000000000','d4000000-0000-4000-8000-000000000004','authenticated','authenticated','v2-concurrent-interest@localhost.test','',now(),now(),now()),
 ('00000000-0000-0000-0000-000000000000','e5000000-0000-4000-8000-000000000005','authenticated','authenticated','v2-concurrent-topic@localhost.test','',now(),now(),now());
insert into public.country_eligibility(country_code,registration_enabled,discovery_enabled)
values ('US',true,true) on conflict(country_code) do update set registration_enabled=true;
insert into public.general_locations(country_code,region,locality,reference_latitude,reference_longitude,resolution_status)
values ('US','TX','Concurrency Test',30.267,-97.743,'resolved') on conflict(country_code,region,locality) do nothing;
insert into public.interests(slug,label) values ('conc-i1','Concurrent I1'),('conc-i2','Concurrent I2'),('conc-i3','Concurrent I3'),('conc-i4','Concurrent I4');
insert into public.topics(slug,label) values ('conc-t1','Concurrent T1'),('conc-t2','Concurrent T2');
insert into public.profiles(user_id,display_name,location_id)
select id,'Concurrent Test', (select id from public.general_locations where locality='Concurrency Test') from app_private.accounts
where id in ('d4000000-0000-4000-8000-000000000004','e5000000-0000-4000-8000-000000000005');
insert into app_private.profile_private(user_id,date_of_birth)
values ('d4000000-0000-4000-8000-000000000004',current_date - interval '25 years'),('e5000000-0000-4000-8000-000000000005',current_date - interval '25 years');
insert into public.user_interests(user_id,interest_id)
select a.id,i.id from app_private.accounts a cross join public.interests i
where a.id in ('d4000000-0000-4000-8000-000000000004','e5000000-0000-4000-8000-000000000005') and i.slug like 'conc-i%';
insert into public.user_topics(user_id,topic_id)
select a.id,t.id from app_private.accounts a cross join public.topics t
where a.id in ('d4000000-0000-4000-8000-000000000004','e5000000-0000-4000-8000-000000000005') and t.slug like 'conc-t%';
select app_private.complete_onboarding('d4000000-0000-4000-8000-000000000004');
select app_private.complete_onboarding('e5000000-0000-4000-8000-000000000005');
