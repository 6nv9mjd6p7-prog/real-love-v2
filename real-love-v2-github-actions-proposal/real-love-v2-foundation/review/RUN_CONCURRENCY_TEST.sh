#!/usr/bin/env bash
set -euo pipefail
: "${LOCAL_DATABASE_URL:?Set LOCAL_DATABASE_URL to a fresh disposable local Supabase PostgreSQL URI}"
cd "$(dirname "$0")/.."
psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -f review/CONCURRENCY_SETUP.sql
cleanup() { psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -f review/CONCURRENCY_CLEANUP.sql >/dev/null || true; }
trap cleanup EXIT
# Both statements must not commit. Each attempts to remove one of four interests,
# and one of two topics: together they would leave the account ineligible.
run_pair() {
  local user_id="$1" table="$2" catalog="$3" column="$4" first="$5" second="$6" out1 out2 pid
  out1=$(mktemp); out2=$(mktemp)
  local timeout_sql="set lock_timeout = '10s'; set statement_timeout = '15s';"
  ( psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -c "$timeout_sql begin; delete from public.$table where user_id='$user_id' and $column=(select id from public.$catalog where slug='$first'); select pg_sleep(2); commit;" >"$out1" 2>&1 ) & pid=$!
  sleep 0.4
  if psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -c "$timeout_sql begin; delete from public.$table where user_id='$user_id' and $column=(select id from public.$catalog where slug='$second'); commit;" >"$out2" 2>&1; then
    echo "FAIL: concurrent $table operations both committed"; cat "$out1" "$out2"; wait "$pid" || true; exit 1
  fi
  if ! wait "$pid"; then echo "FAIL: first transaction did not commit"; cat "$out1"; exit 1; fi
  if ! grep -q 'COMMIT' "$out1"; then echo "FAIL: first session missing COMMIT"; cat "$out1"; exit 1; fi
  if ! grep -q 'At least three active interests and one active topic required' "$out2"; then
    echo "FAIL: second session did not fail for expected eligibility reason"; cat "$out2"; exit 1;
  fi
  if grep -Eiq 'deadlock detected|lock timeout|canceling statement due to statement timeout' "$out1" "$out2"; then
    echo 'FAIL: deadlock or lock timeout detected'; cat "$out1" "$out2"; exit 1;
  fi
  echo "PASS: second concurrent $table delete rejected"; cat "$out2"
  rm -f "$out1" "$out2"
}
run_pair d4000000-0000-4000-8000-000000000004 user_interests interests interest_id conc-i1 conc-i2
run_pair e5000000-0000-4000-8000-000000000005 user_topics topics topic_id conc-t1 conc-t2
# Verify exact final cardinalities after both races.
psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" -c "select user_id,count(*) from public.user_interests where user_id='d4000000-0000-4000-8000-000000000004' group by user_id; select user_id,count(*) from public.user_topics where user_id='e5000000-0000-4000-8000-000000000005' group by user_id;"

# Assert both races leave safe counts; fail rather than merely printing counts.
psql -X -v ON_ERROR_STOP=1 "$LOCAL_DATABASE_URL" <<'SQL'
do $$ begin
 if (select count(*) from public.user_interests where user_id='d4000000-0000-4000-8000-000000000004') <> 3 then
  raise exception 'FAIL: concurrency left incorrect interest count'; end if;
 if (select count(*) from public.user_topics where user_id='e5000000-0000-4000-8000-000000000005') <> 1 then
  raise exception 'FAIL: concurrency left incorrect topic count'; end if;
end $$;
SQL
