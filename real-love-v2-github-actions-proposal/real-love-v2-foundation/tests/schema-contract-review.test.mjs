import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const sql = readFileSync(new URL('../supabase/migrations/20261030000000_phase_a_foundation.sql', import.meta.url), 'utf8');
const tables = [...sql.matchAll(/create table (public|app_private)\.(\w+) \(/g)];
test('exactly 11 Phase A tables; sensitive settings private', () => {
  assert.equal(tables.length, 11);
  for (const name of ['accounts','profile_private','privacy_settings','discovery_settings']) assert.match(sql, new RegExp(`create table app_private\\.${name} \\(`));
});
test('all tables enabled and forced RLS', () => {
  for (const [, schema, table] of tables) {
    assert.ok(sql.includes(`alter table ${schema}.${table} enable row level security;`));
    assert.ok(sql.includes(`alter table ${schema}.${table} force row level security;`));
  }
});
test('approved status, preferences, and country controls', () => {
  for (const token of ["'onboarding'","'active'","'restricted'","'suspended'","'banned'","'deleting'",'onboarding_step','onboarded_at','max_distance_miles integer not null default 50','anywhere boolean not null default false',"connection_intention text not null default 'friendship'",'minimum_age integer not null default 18','maximum_age integer default null','resolution_status','reference_latitude','reference_longitude','registration_enabled','discovery_enabled','effective_at']) assert.ok(sql.includes(token), token);
  assert.doesNotMatch(sql,/create policy/i);
});
