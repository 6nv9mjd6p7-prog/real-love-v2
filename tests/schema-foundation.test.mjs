import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261030000000_phase_a_foundation.sql', import.meta.url),'utf8');
test('all Phase A tables present',()=>{
  for(const t of ['profiles','general_locations','interests','topics','user_interests','user_topics','country_eligibility']) assert.ok(sql.includes(`create table public.${t} (`),t);
  for(const name of ['accounts','profile_private','privacy_settings','discovery_settings']) assert.ok(sql.includes(`create table app_private.${name} (`));
});
test('explicit RLS on every defined table; no allow policies',()=>{
  for(const [,schema,table] of sql.matchAll(/create table (public|app_private)\.(\w+) \(/g)) assert.ok(sql.includes(`alter table ${schema}.${table} enable row level security;`), `${schema}.${table}`);
  assert.doesNotMatch(sql,/create policy\s/i);
});
test('private schema not exposed in local API config',()=>{
  const config=readFileSync(new URL('../supabase/config.toml',import.meta.url),'utf8');
  assert.doesNotMatch(config,/schemas\s*=\s*\[[^\]]*app_private/);
});
