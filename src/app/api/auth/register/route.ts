import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";

export const runtime = "nodejs";

const registration = z.object({
  email: z.email().max(254),
  password: z.string().min(12).max(128),
}).strict();

const commonHeaders = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
};

function fail(message: string, status: number) {
  return NextResponse.json({ error: message }, { status, headers: commonHeaders });
}

export async function POST(request: NextRequest) {
  // State-changing cross-origin requests must never create accounts.
  const origin = request.headers.get("origin");
  if (!origin || origin !== request.nextUrl.origin ||
      request.headers.get("sec-fetch-site") === "cross-site") {
    return fail("Request origin not permitted.", 403);
  }
  if (!request.headers.get("content-type")?.toLowerCase().includes("application/json")) {
    return fail("Expected a JSON request.", 415);
  }
  const declaredLength = Number(request.headers.get("content-length") ?? 0);
  if (!Number.isFinite(declaredLength) || declaredLength > 4096) {
    return fail("Request body is too large.", 413);
  }

  let raw: unknown;
  try {
    const body = await request.text();
    if (body.length > 4096) return fail("Request body is too large.", 413);
    raw = JSON.parse(body);
  } catch {
    return fail("Invalid JSON.", 400);
  }
  const parsed = registration.safeParse(raw);
  if (!parsed.success) {
    return fail("Enter a valid email and a password of at least 12 characters.", 400);
  }
  const url = process.env.SUPABASE_URL;
  const publishableKey = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !publishableKey) {
    return fail("Registration is not available.", 503);
  }
  let base: URL;
  try {
    base = new URL(url);
    if (!["http:", "https:"].includes(base.protocol) || base.username || base.password ||
        base.search || base.hash || base.pathname !== "/" ||
        (base.protocol === "http:" && !["127.0.0.1", "localhost"].includes(base.hostname))) {
      return fail("Registration is not available.", 503);
    }
  } catch {
    return fail("Registration is not available.", 503);
  }

  try {
    const response = await fetch(new URL("/auth/v1/signup", base), {
      method: "POST",
      headers: {
        apikey: publishableKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        email: parsed.data.email.trim().toLowerCase(),
        password: parsed.data.password,
      }),
      cache: "no-store",
      signal: AbortSignal.timeout(10000),
    });

    if (response.status === 429) return fail("Too many attempts. Please try again later.", 429);
    if (!response.ok) {
      // Do not reveal whether an account already exists.
      return fail("Registration could not be completed. Check your information and try again.", 400);
    }
    // Never return an access token, refresh token, or Supabase user metadata.
    return NextResponse.json({
      message: "Check your email for a verification link before signing in.",
    }, { status: 202, headers: commonHeaders });
  } catch {
    return fail("The registration service is temporarily unavailable.", 503);
  }
}
