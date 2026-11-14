import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync, existsSync } from 'node:fs';
const read=p=>readFileSync(new URL(`../${p}`,import.meta.url),'utf8');
test('local Supabase has isolated project ID and required services',()=>{
  const c=read('supabase/config.toml');
  assert.match(c,/project_id\s*=\s*"real-love-v2-local"/);
  for (const section of ['api','db','auth','auth.email','storage','inbucket']) assert.ok(c.includes(`[${section}]`));
  assert.match(c,/enable_confirmations\s*=\s*true/);
  assert.match(c,/enable_anonymous_sign_ins\s*=\s*false/);
});
test('env template uses loopback and does not contain actual secrets',()=>{
  const t=read('.env.example');
  assert.match(t,/NEXT_PUBLIC_SUPABASE_URL=http:\/\/127\.0\.0\.1:54321/);
  assert.match(t,/NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY=REPLACE_WITH_LOCAL_PUBLISHABLE_KEY/);
  assert.doesNotMatch(t,/^NEXT_PUBLIC_.*(?:SERVICE_ROLE|SECRET|PASSWORD)=/m);
});
test('no migrations accidentally imported from V1',()=>{
 assert.ok(existsSync(new URL('../supabase/migrations/',import.meta.url)));
});
