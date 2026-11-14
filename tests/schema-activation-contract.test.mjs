import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261030000000_phase_a_foundation.sql',import.meta.url),'utf8');
test('activation prerequisites enforced with a database trigger',()=>{
 for(const expected of ['accounts_activation_guard','app_private.enforce_activation_eligibility','current_date - interval \'18 years\'','interests_count < 3','topics_count < 1','ce.registration_enabled','ce.effective_at <= now()','new.onboarded_at is null']) assert.ok(sql.includes(expected),expected);
});
test('auth users ownership and restrictive table access',()=>{
 assert.match(sql,/create table app_private\.accounts \(\s*id uuid primary key references auth\.users\(id\)/);
 assert.match(sql,/revoke all on schema app_private from public, anon, authenticated/);
 assert.doesNotMatch(sql,/create policy/i);
});
