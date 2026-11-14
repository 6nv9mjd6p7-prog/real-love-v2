import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261030000000_phase_a_foundation.sql',import.meta.url),'utf8');
test('shared account locks serialize eligibility edits and onboarding',()=>{
 assert.match(sql,/create function app_private\.lock_eligibility_account\(\)/);
 for(const t of ['profiles','private_profiles','interests','topics']) assert.match(sql,new RegExp('create trigger lock_'+t+' before insert or update or delete'));
 assert.match(sql,/where id=v_user for update/);
 assert.match(sql,/where id=p_user_id and status='onboarding' for update/);
});
test('first activation checks country, reactivation validates ongoing profile',()=>{
 assert.match(sql,/perform app_private\.assert_profile_complete\(new\.id\);/);
 assert.match(sql,/old\.onboarded_at is null/);
 assert.doesNotMatch(sql,/old\.status is distinct from 'active'/);
});
