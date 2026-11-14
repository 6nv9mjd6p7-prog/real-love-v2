import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync, existsSync } from "node:fs";

const read = (path) => readFileSync(new URL(`../${path}`, import.meta.url), "utf8");
test("uses a Next.js App Router foundation", () => {
  const p = JSON.parse(read("package.json"));
  assert.ok(p.dependencies.next);
  assert.ok(existsSync(new URL("../src/app/layout.tsx", import.meta.url)));
  assert.ok(existsSync(new URL("../src/app/page.tsx", import.meta.url)));
});
test("does not ship a database connection or privileged client key", () => {
  assert.doesNotMatch(read(".env.example"), /^(?!#).*SERVICE_ROLE/m);
  assert.doesNotMatch(read("src/app/page.tsx"), /supabase|service_role/i);
});
test("supports ordinary mobile scaling and skip navigation", () => {
  assert.match(read("src/app/layout.tsx"), /initialScale: 1/);
  assert.match(read("src/app/layout.tsx"), /skip-link/);
  assert.match(read("src/app/page.tsx"), /id="main-content"/);
});
