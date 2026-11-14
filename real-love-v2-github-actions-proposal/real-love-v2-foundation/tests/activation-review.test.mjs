import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261030000000_phase_a_foundation.sql',import.meta.url),'utf8');
test('activation is guarded transactionally, and cannot be invoked by client roles',()=>{
 for(const needle of ['create function app_private.complete_onboarding','security invoker','for update;','update app_private.accounts','create trigger accounts_activation_guard',"gl.resolution_status='resolved'",'interests_count < 3','topics_count < 1','current_date - interval \'18 years\'','revoke all on function app_private.complete_onboarding(uuid) from public, anon, authenticated']) assert.ok(sql.includes(needle),needle);
});
test('no application direct account activation privileges or permissive policies',()=>{
 assert.ok(sql.includes('revoke all on all tables in schema app_private from public, anon, authenticated'));
 assert.doesNotMatch(sql,/create policy\s/i);
});
