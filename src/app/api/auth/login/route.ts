import { NextRequest, NextResponse } from "next/server";
import { z } from "zod";
import {
  accessCookie, authConfig, authError, authHeaders, refreshCookie,
  requireSameOrigin, sessionCookieOptions,
} from "@/lib/auth/response";

export const runtime = "nodejs";

const inputSchema = z.object({
  email: z.email().max(254),
  password: z.string().min(1).max(128),
}).strict();

type TokenResponse = {
  access_token?: string;
  refresh_token?: string;
  expires_in?: number;
  user?: { email_confirmed_at?: string | null };
};

export async function POST(request: NextRequest) {
  if (!requireSameOrigin(request)) return authError("Request origin not permitted.", 403);
  if (!request.headers.get("content-type")?.includes("application/json")) return authError("Expected JSON.", 415);
  const bodyText = await request.text();
  if (bodyText.length > 4096) return authError("Request too large.", 413);
  let body: unknown;
  try { body = JSON.parse(bodyText); } catch { return authError("Invalid request.", 400); }
  const parsed = inputSchema.safeParse(body);
  if (!parsed.success) return authError("Enter a valid email and password.", 400);
  const config = authConfig();
  if (!config) return authError("Login is temporarily unavailable.", 503);
  try {
    const remote = await fetch(new URL("/auth/v1/token?grant_type=password", config.url), {
      method: "POST",
      headers: { apikey: config.key, "Content-Type": "application/json" },
      body: JSON.stringify({
        email: parsed.data.email.trim().toLowerCase(),
        password: parsed.data.password,
      }),
      cache: "no-store",
      signal: AbortSignal.timeout(10000),
    });
    if (remote.status === 429) return authError("Too many attempts. Try again later.", 429);
    if (!remote.ok) return authError("Incorrect credentials or unverified email.", 401);
    const tokens = await remote.json() as TokenResponse;
    if (!tokens.access_token || !tokens.refresh_token || !tokens.user?.email_confirmed_at ||
        !Number.isFinite(tokens.expires_in) || !tokens.expires_in || tokens.expires_in < 1) {
      return authError("Verify your email before signing in.", 401);
    }
    const response = NextResponse.json({ message: "Signed in." }, { headers: authHeaders });
    response.cookies.set(accessCookie, tokens.access_token, sessionCookieOptions(request, Math.min(Math.floor(tokens.expires_in), 3600)));
    response.cookies.set(refreshCookie, tokens.refresh_token, sessionCookieOptions(request, 7 * 86400));
    return response;
  } catch {
    return authError("Login is temporarily unavailable.", 503);
  }
}
