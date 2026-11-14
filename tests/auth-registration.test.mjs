import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = (p) => readFileSync(new URL(`../${p}`, import.meta.url), "utf8");

test("registration sends only validated credentials to Supabase Auth", () => {
  const route = read("src/app/api/auth/register/route.ts");
  assert.match(route, /registration\.safeParse\(raw\)/);
  assert.match(route, /\/auth\/v1\/signup/);
  assert.match(route, /request\.headers\.get\("origin"\)/);
  assert.match(route, /"Cache-Control": "no-store"/);
  assert.doesNotMatch(route, /service_role|SUPABASE_SECRET|raw_app_meta_data/i);
  assert.match(route, /status: 202/);
});

test("registration UI has labeled email and password, loading and feedback", () => {
  const page = read("src/app/register/page.tsx");
  assert.match(page, /id="registration-email"/);
  assert.match(page, /htmlFor="registration-email"/);
  assert.match(page, /type="email"/);
  assert.match(page, /autoComplete="new-password"/);
  assert.match(page, /role="alert"/);
  assert.match(page, /role="status"/);
  assert.match(page, /disabled=\{busy\}/);
});

test("registration uses only local publishable server configuration", () => {
  const route = read("src/app/api/auth/register/route.ts");
  const env = read(".env.example");
  assert.match(route, /process\.env\.SUPABASE_URL/);
  assert.match(route, /process\.env\.SUPABASE_PUBLISHABLE_KEY/);
  assert.match(env, /^SUPABASE_URL=http:\/\/127\.0\.0\.1:54321/m);
  assert.match(env, /^SUPABASE_PUBLISHABLE_KEY=REPLACE_WITH_LOCAL_PUBLISHABLE_KEY/m);
  assert.doesNotMatch(env, /^SUPABASE_SECRET_KEY=/m);
});
