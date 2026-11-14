-- Phase A Step 4 final safeguard: account identity cannot be reassigned.
-- A new migration preserves the already executed foundation migration's history.
begin;
create function app_private.prevent_account_id_change()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if new.id is distinct from old.id then
    raise exception 'account id is immutable' using errcode = '23514';
  end if;
  return new;
end;
$$;
revoke all on function app_private.prevent_account_id_change() from public, anon, authenticated;
create trigger immutable_account_id
before update on app_private.accounts
for each row execute function app_private.prevent_account_id_change();
commit;
