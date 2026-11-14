import test from 'node:test';
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
const sql=readFileSync(new URL('../supabase/migrations/20261030000000_phase_a_foundation.sql', import.meta.url),'utf8');
test('onboarding bootstrap is trusted and inaccessible to clients',()=>{
 for(const s of ['create trigger on_auth_user_created after insert on auth.users','security definer','revoke all on function app_private.bootstrap_account() from public, anon, authenticated']) assert.ok(sql.includes(s),s);
});
test('active member validation guards all critical mutations',()=>{
 for(const s of ['active_profile_guard','active_dob_guard','active_interests_guard','active_topics_guard','active_location_reference_guard','active_interest_catalog_guard','active_topic_catalog_guard','app_private.assert_profile_complete']) assert.ok(sql.includes(s),s);
});
test('country registration rule only applies on entry to active',()=>{
 assert.ok(sql.includes('old.onboarded_at is null'));
 assert.ok(sql.includes('ce.registration_enabled'));
});
test('all timestamped tables have update triggers',()=>{
 for(const t of ['accounts','profiles','profile_private','privacy_settings','discovery_settings','country_eligibility']) assert.ok(sql.includes(`create trigger touch_${t} `),t);
});
