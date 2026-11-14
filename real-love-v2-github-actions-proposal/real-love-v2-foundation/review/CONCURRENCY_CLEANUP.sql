\set ON_ERROR_STOP on
-- Never run outside disposable local DB.
delete from auth.users where id in ('d4000000-0000-4000-8000-000000000004','e5000000-0000-4000-8000-000000000005');
delete from public.interests where slug like 'conc-i%';
delete from public.topics where slug like 'conc-t%';
delete from public.general_locations where locality='Concurrency Test';
