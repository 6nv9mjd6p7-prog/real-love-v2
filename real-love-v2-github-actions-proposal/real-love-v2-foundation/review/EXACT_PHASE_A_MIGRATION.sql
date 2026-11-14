-- Corrected Phase A schema for Chat 01 re-review. PostgreSQL execution still required.
-- Local-only; do not link a hosted project or use V1 credentials.
-- Tables are locked down by default. Application policies arrive in the authorization step.
begin;

create schema if not exists app_private;
revoke all on schema app_private from public, anon, authenticated;

create table app_private.accounts (
  id uuid primary key references auth.users(id) on delete cascade,
  status text not null default 'onboarding' check (status in ('onboarding','active','restricted','suspended','banned','deleting')),
  onboarding_step text not null default 'identity' check (char_length(onboarding_step) between 1 and 80),
  onboarded_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.general_locations (
  id bigint generated always as identity primary key,
  country_code text not null check (country_code ~ '^[A-Z]{2}$'),
  region text,
  locality text,
  -- Approximate reference point only; never store a precise home address or raw GPS point here.
  reference_latitude numeric(6,3) check (reference_latitude between -90 and 90),
  reference_longitude numeric(6,3) check (reference_longitude between -180 and 180),
  resolution_status text not null default 'unresolved' check (resolution_status in ('unresolved','resolved','unavailable')),
  check ((reference_latitude is null) = (reference_longitude is null)),
  check (resolution_status <> 'resolved' or reference_latitude is not null),
  unique nulls not distinct (country_code, region, locality)
);

create table public.profiles (
  user_id uuid primary key references app_private.accounts(id) on delete cascade,
  display_name text not null check (char_length(trim(display_name)) between 1 and 80),
  bio text check (char_length(bio) <= 1000),
  location_id bigint references public.general_locations(id),
  discoverable boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.profile_private (
  user_id uuid primary key references app_private.accounts(id) on delete cascade,
  date_of_birth date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.privacy_settings (
  user_id uuid primary key references app_private.accounts(id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table app_private.discovery_settings (
  user_id uuid primary key references app_private.accounts(id) on delete cascade,
  max_distance_miles integer not null default 50 check (max_distance_miles in (10,25,50,100) ),
  anywhere boolean not null default false,
  connection_intention text not null default 'friendship' check (connection_intention in ('friendship')),
  minimum_age integer not null default 18 check (minimum_age between 18 and 100),
  maximum_age integer default null check (maximum_age between 18 and 100 or maximum_age is null),
  -- NULL means 100+ (unbounded upper preference), not an unknown preference.
  check (maximum_age is null or maximum_age >= minimum_age),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.interests (
  id bigint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label text not null unique,
  active boolean not null default true
);

create table public.topics (
  id bigint generated always as identity primary key,
  slug text not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  label text not null unique,
  active boolean not null default true
);

create table public.user_interests (
  user_id uuid not null references app_private.accounts(id) on delete cascade,
  interest_id bigint not null references public.interests(id),
  primary key (user_id, interest_id)
);

create table public.user_topics (
  user_id uuid not null references app_private.accounts(id) on delete cascade,
  topic_id bigint not null references public.topics(id),
  primary key (user_id, topic_id)
);

create table public.country_eligibility (
  country_code text primary key check (country_code ~ '^[A-Z]{2}$'),
  registration_enabled boolean not null default false,
  discovery_enabled boolean not null default false,
  effective_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Normalize update timestamps at the database boundary.
create function app_private.touch_updated_at()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at := now();
  return new;
end;
$$;
revoke all on function app_private.touch_updated_at() from public, anon, authenticated;

create trigger touch_accounts before update on app_private.accounts
for each row execute function app_private.touch_updated_at();
create trigger touch_profiles before update on public.profiles
for each row execute function app_private.touch_updated_at();
create trigger touch_profile_private before update on app_private.profile_private
for each row execute function app_private.touch_updated_at();
create trigger touch_privacy_settings before update on app_private.privacy_settings
for each row execute function app_private.touch_updated_at();
create trigger touch_discovery_settings before update on app_private.discovery_settings
for each row execute function app_private.touch_updated_at();
create trigger touch_country_eligibility before update on public.country_eligibility
for each row execute function app_private.touch_updated_at();

-- Central current-data checks for an active member. Country registration eligibility
-- is deliberately NOT checked here: changing supported countries never bans an
-- established account by itself. The country rule applies only on activation.
create function app_private.assert_profile_complete(p_user_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  dob date;
  ok_profile boolean;
  interests_count integer;
  topics_count integer;
begin
  select pp.date_of_birth into dob
  from app_private.profile_private pp where pp.user_id = p_user_id;
  if dob is null or dob > (current_date - interval '18 years')::date then
    raise exception 'Account must be at least 18';
  end if;
  select exists (
    select 1 from public.profiles p
    join public.general_locations gl on gl.id=p.location_id
    where p.user_id=p_user_id and length(btrim(p.display_name)) between 1 and 80
      and gl.resolution_status='resolved'
      and gl.reference_latitude is not null and gl.reference_longitude is not null
  ) into ok_profile;
  if not ok_profile then
    raise exception 'Valid profile, display name, and resolved location required';
  end if;
  select count(*) into interests_count from public.user_interests ui
    join public.interests i on i.id=ui.interest_id and i.active
    where ui.user_id=p_user_id;
  select count(*) into topics_count from public.user_topics ut
    join public.topics t on t.id=ut.topic_id and t.active
    where ut.user_id=p_user_id;
  if interests_count < 3 or topics_count < 1 then
    raise exception 'At least three active interests and one active topic required';
  end if;
end;
$$;
revoke all on function app_private.assert_profile_complete(uuid) from public, anon, authenticated;

create function app_private.enforce_activation_eligibility()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.status = 'onboarding' and new.onboarded_at is not null then
    raise exception 'Onboarding account cannot have onboarded_at';
  end if;
  if new.status <> 'active' then return new; end if;
  if new.onboarded_at is null then raise exception 'Active account requires onboarded_at'; end if;
  -- Do not apply newly changed registration-country controls to existing members.
  perform app_private.assert_profile_complete(new.id);
  -- Registration-country controls apply only to first onboarding, not reactivation.
  if tg_op = 'INSERT' or old.onboarded_at is null then
    if not exists (
      select 1 from public.profiles p
      join public.general_locations gl on gl.id=p.location_id
      join public.country_eligibility ce on ce.country_code=gl.country_code
      where p.user_id=new.id and ce.registration_enabled and ce.effective_at <= now()
    ) then
      raise exception 'Account registration country is not eligible';
    end if;
  end if;
  return new;
end;
$$;
revoke all on function app_private.enforce_activation_eligibility() from public, anon, authenticated;
create trigger accounts_activation_guard
before insert or update of status, onboarded_at on app_private.accounts
for each row execute function app_private.enforce_activation_eligibility();

-- A foreign-key owner is established at INSERT and can never be reassigned.
-- This covers both single-row profile records and selection junction tables.
create function app_private.prevent_user_id_change()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.user_id is distinct from old.user_id then
    raise exception 'user_id is immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function app_private.prevent_user_id_change() from public, anon, authenticated;
create trigger immutable_profile_owner before update on public.profiles
for each row execute function app_private.prevent_user_id_change();
create trigger immutable_private_profile_owner before update on app_private.profile_private
for each row execute function app_private.prevent_user_id_change();
create trigger immutable_privacy_owner before update on app_private.privacy_settings
for each row execute function app_private.prevent_user_id_change();
create trigger immutable_discovery_owner before update on app_private.discovery_settings
for each row execute function app_private.prevent_user_id_change();
create trigger immutable_interest_owner before update on public.user_interests
for each row execute function app_private.prevent_user_id_change();
create trigger immutable_topic_owner before update on public.user_topics
for each row execute function app_private.prevent_user_id_change();

-- Serialize eligibility-critical writes and onboarding completion using the SAME
-- accounts row lock, acquired BEFORE changing selections or required profile data.
-- This prevents two transactions independently removing the final required rows.
-- For user_id transfers, lock both accounts in UUID order to avoid deadlocks.
create function app_private.lock_eligibility_account()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_user uuid;
begin
  for v_user in
    select distinct x.uid from (
      select case when tg_op <> 'INSERT' then old.user_id end as uid
      union all
      select case when tg_op <> 'DELETE' then new.user_id end as uid
    ) x where x.uid is not null order by x.uid
  loop
    perform 1 from app_private.accounts where id=v_user for update;
  end loop;
  return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function app_private.lock_eligibility_account() from public, anon, authenticated;
create trigger lock_profiles before insert or update or delete on public.profiles
for each row execute function app_private.lock_eligibility_account();
create trigger lock_private_profiles before insert or update or delete on app_private.profile_private
for each row execute function app_private.lock_eligibility_account();
create trigger lock_interests before insert or update or delete on public.user_interests
for each row execute function app_private.lock_eligibility_account();
create trigger lock_topics before insert or update or delete on public.user_topics
for each row execute function app_private.lock_eligibility_account();

-- Shared catalog/location changes must also lock affected accounts before mutation.
create function app_private.lock_shared_eligibility_accounts()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_user uuid;
begin
  for v_user in
    select distinct affected.user_id from (
      select p.user_id from public.profiles p where tg_table_name='general_locations' and p.location_id=old.id
      union all
      select ui.user_id from public.user_interests ui where tg_table_name='interests' and ui.interest_id=old.id
      union all
      select ut.user_id from public.user_topics ut where tg_table_name='topics' and ut.topic_id=old.id
    ) affected order by affected.user_id
  loop
    perform 1 from app_private.accounts where id=v_user for update;
  end loop;
  return case when tg_op='DELETE' then old else new end;
end;
$$;
revoke all on function app_private.lock_shared_eligibility_accounts() from public, anon, authenticated;
create trigger lock_general_locations before update or delete on public.general_locations
for each row execute function app_private.lock_shared_eligibility_accounts();
create trigger lock_catalog_interests before update or delete on public.interests
for each row execute function app_private.lock_shared_eligibility_accounts();
create trigger lock_catalog_topics before update or delete on public.topics
for each row execute function app_private.lock_shared_eligibility_accounts();

-- Run following a change to membership-critical data. Operations are rejected
-- when they would leave an already-active member with incomplete onboarding data.
create function app_private.protect_active_profile()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_user uuid;
begin
  v_user := case when tg_op = 'DELETE' then old.user_id else new.user_id end;
  if exists (select 1 from app_private.accounts a where a.id=v_user and a.status='active') then
    perform app_private.assert_profile_complete(v_user);
  end if;
  return null;
end;
$$;
revoke all on function app_private.protect_active_profile() from public, anon, authenticated;
create trigger active_profile_guard after insert or update or delete on public.profiles
for each row execute function app_private.protect_active_profile();
create trigger active_dob_guard after insert or update or delete on app_private.profile_private
for each row execute function app_private.protect_active_profile();
create trigger active_interests_guard after insert or update or delete on public.user_interests
for each row execute function app_private.protect_active_profile();
create trigger active_topics_guard after insert or update or delete on public.user_topics
for each row execute function app_private.protect_active_profile();

create function app_private.protect_shared_reference()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_user uuid;
begin
  if tg_table_name='general_locations' then
    for v_user in select p.user_id from public.profiles p
       join app_private.accounts a on a.id=p.user_id and a.status='active'
       where p.location_id=old.id loop
      perform app_private.assert_profile_complete(v_user);
    end loop;
  elsif tg_table_name='interests' then
    for v_user in select ui.user_id from public.user_interests ui
       join app_private.accounts a on a.id=ui.user_id and a.status='active'
       where ui.interest_id=old.id loop
      perform app_private.assert_profile_complete(v_user);
    end loop;
  elsif tg_table_name='topics' then
    for v_user in select ut.user_id from public.user_topics ut
       join app_private.accounts a on a.id=ut.user_id and a.status='active'
       where ut.topic_id=old.id loop
      perform app_private.assert_profile_complete(v_user);
    end loop;
  end if;
  return null;
end;
$$;
revoke all on function app_private.protect_shared_reference() from public, anon, authenticated;
create trigger active_location_reference_guard after update or delete on public.general_locations
for each row execute function app_private.protect_shared_reference();
create trigger active_interest_catalog_guard after update or delete on public.interests
for each row execute function app_private.protect_shared_reference();
create trigger active_topic_catalog_guard after update or delete on public.topics
for each row execute function app_private.protect_shared_reference();

-- Authorized account bootstrap: a trusted auth.users insertion creates an
-- onboarding account. No browser/client-facing account table grants are needed.
create function app_private.bootstrap_account()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into app_private.accounts (id, status) values (new.id, 'onboarding');
  return new;
end;
$$;
revoke all on function app_private.bootstrap_account() from public, anon, authenticated;
create trigger on_auth_user_created after insert on auth.users
for each row execute function app_private.bootstrap_account();

-- Only a trusted server/database role may perform completion. A client cannot
-- set an active status, invoke this function, or change account ownership.
create function app_private.complete_onboarding(p_user_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
begin
  perform 1 from app_private.accounts
    where id=p_user_id and status='onboarding' for update;
  if not found then raise exception 'Not eligible for onboarding completion'; end if;
  update app_private.accounts set status='active', onboarded_at=now()
    where id=p_user_id and status='onboarding';
end;
$$;
revoke all on function app_private.complete_onboarding(uuid) from public, anon, authenticated;

-- Default deny: RLS is enabled, with no policies until the authorization contract is verified.
-- FORCE RLS applies to table owners; privileged BYPASSRLS roles still bypass RLS.
alter table app_private.accounts enable row level security;
alter table public.profiles enable row level security;
alter table public.general_locations enable row level security;
alter table app_private.privacy_settings enable row level security;
alter table app_private.discovery_settings enable row level security;
alter table public.interests enable row level security;
alter table public.topics enable row level security;
alter table public.user_interests enable row level security;
alter table public.user_topics enable row level security;
alter table public.country_eligibility enable row level security;
alter table app_private.profile_private enable row level security;

-- Apply FORCE RLS consistently with the comment; it does not constrain service_role/BYPASSRLS.
alter table app_private.accounts force row level security;
alter table public.profiles force row level security;
alter table public.general_locations force row level security;
alter table app_private.privacy_settings force row level security;
alter table app_private.discovery_settings force row level security;
alter table public.interests force row level security;
alter table public.topics force row level security;
alter table public.user_interests force row level security;
alter table public.user_topics force row level security;
alter table public.country_eligibility force row level security;
alter table app_private.profile_private force row level security;

revoke all on all tables in schema app_private from public, anon, authenticated;
revoke all on all sequences in schema app_private from public, anon, authenticated;
revoke all on public.profiles, public.general_locations, public.interests,
  public.topics, public.user_interests, public.user_topics, public.country_eligibility
  from public, anon, authenticated;

commit;
