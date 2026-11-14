# Real Love V2

Clean V2 technical foundation. **Do not connect this project to V1's database.**

## Scope

Phase A Steps 2–3 scaffold: Next.js App Router, TypeScript, Tailwind CSS, basic server/client separation, accessibility baseline, offline source tests, and CI.

This is not a working social application. No authentication, profiles, or backend integration has been built. Local Supabase configuration exists, but requires Docker, Supabase CLI, and dependency installation before runtime verification.

## Requirements

- Node.js 22.13+ and npm
- No paid infrastructure required

## Local setup

```sh
cp .env.example .env.local
npm install
npm run dev
```

Open http://localhost:3000. Then run `npm run check` for tests, lint, typecheck, and production build. Commit the generated `package-lock.json` **before** running CI; use `npm ci` thereafter.

## Directory map

- `src/app`: routes and root page (App Router)
- `src/components/ui`: shared visual components (added after Chat 02 design tokens)
- `src/features`: future feature modules
- `src/lib/server`: server-only data/auth functions
- `src/lib/validation`: shared input contracts
- `src/types`: shared TypeScript definitions
- `tests`: offline foundation assertions

## Safety constraints

- Preserve V1 unchanged.
- No hosting or deployment is configured.
- Never commit `.env.local` or service credentials.
- Do not expose privileged Supabase keys to client components.
- Implement database and RLS **before** profile data flows.

## Current limitations

The archive is not dependency-installed and includes no lockfile because npm registry access was unavailable during generation. CI will fail at `npm ci` until `npm install` generates and commits `package-lock.json`. The app has not undergone a runtime build or browser/mobile QA in this environment.

## Step 3: Local Supabase only

Requires a running Docker-compatible container runtime and a **project-installed pinned Supabase CLI**. On a machine with npm access, run `npm install -D --save-exact supabase` and commit the resulting `package.json` and `package-lock.json` together. If the CLI is installed globally, use `supabase` in place of `npx supabase`. Do **not** use `supabase link`, `supabase login`, or hosted credentials in Phase A.

```sh
# from project root, with Docker running
npx supabase --help
npx supabase start
npx supabase status
cp .env.example .env.local
# replace placeholder key using local `supabase status` output
node scripts/check-local-env.mjs
npm run dev
# when finished
npx supabase stop
```

Local API is configured at 127.0.0.1:54321, PostgreSQL 54322, Studio 54323, and email testing at 54324 (subject to availability and CLI version). The `supabase/config.toml` is local only; there is no hosted project reference. Verification: register a test email later in Step 5 and use the local mail testing UI to confirm it. No real emails should be sent.

**Security:** `.env.local` is ignored. Only the public/publishable key may have `NEXT_PUBLIC_`. Never put secret/service-role keys into frontend code. Local configuration is NOT equivalent to a verified backend. Database migrations and authorization policies are Step 4/6.

**Current blocker:** This environment has neither Docker nor Supabase CLI and npm access is unavailable. No actual local Supabase services have started; never claim auth/database/storage integration tests passed.
