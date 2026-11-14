import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const read = path => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");

test("email confirmation uses local Supabase template and a server exchange", () => {
  const config = read("supabase/config.toml");
  const template = read("supabase/templates/confirmation.html");
  const route = read("src/app/api/auth/confirm/route.ts");
  assert.match(config, /\[auth\.email\.template\.confirmation\]/);
  assert.match(template, /TokenHash/);
  assert.match(route, /\/auth\/v1\/verify/);
  assert.match(route, /token_hash/);
  assert.doesNotMatch(route, /response\.cookies\.set/);
});

test("login only writes HttpOnly credentials after verified sign-in", () => {
  const login = read("src/app/api/auth/login/route.ts");
  const cookies = read("src/lib/auth/response.ts");
  assert.match(login, /\/auth\/v1\/token\?grant_type=password/);
  assert.match(login, /email_confirmed_at/);
  assert.match(login, /refreshCookie/);
  assert.match(cookies, /httpOnly: true/);
  assert.match(cookies, /sameSite: "lax"/);
  assert.doesNotMatch(login, /service_role|SUPABASE_SECRET/i);
});

test("session endpoint validates remote Auth user and withholds account access", () => {
  const route = read("src/app/api/auth/session/route.ts");
  assert.match(route, /\/auth\/v1\/user/);
  assert.match(route, /accountAccess: "not-verified"/);
  assert.match(route, /"Cache-Control"/);
});

test("logout is origin-checked and clears both credentials", () => {
  const route = read("src/app/api/auth/logout/route.ts");
  assert.match(route, /requireSameOrigin\(request\)/);
  assert.match(route, /\/auth\/v1\/logout/);
  assert.match(route, /response\.cookies\.set\(accessCookie, ""/);
  assert.match(route, /response\.cookies\.set\(refreshCookie, ""/);
});
