import { NextRequest, NextResponse } from "next/server";
import {
  accessCookie, authConfig, authHeaders, refreshCookie,
  requireSameOrigin, sessionCookieOptions,
} from "@/lib/auth/response";

export const runtime = "nodejs";

export async function POST(request: NextRequest) {
  if (!requireSameOrigin(request)) {
    return NextResponse.json({ error: "Request origin not permitted." }, { status: 403, headers: authHeaders });
  }
  const config = authConfig();
  const token = request.cookies.get(accessCookie)?.value;
  if (config && token) {
    try {
      // Revoke the Supabase session when possible. Token invalidation remains
      // subject to Supabase JWT lifetime; subsequent app calls must reauthorize.
      await fetch(new URL("/auth/v1/logout", config.url), {
        method: "POST",
        headers: { apikey: config.key, Authorization: `Bearer ${token}` },
        cache: "no-store",
        signal: AbortSignal.timeout(10000),
      });
    } catch {
      // Local cookies are still cleared when Supabase is temporarily unreachable.
    }
  }
  const response = NextResponse.json({ message: "Signed out on this device." }, { headers: authHeaders });
  response.cookies.set(accessCookie, "", sessionCookieOptions(request, 0));
  response.cookies.set(refreshCookie, "", sessionCookieOptions(request, 0));
  return response;
}
