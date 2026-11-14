import { NextRequest, NextResponse } from "next/server";
import { accessCookie, authConfig, authHeaders } from "@/lib/auth/response";

export const runtime = "nodejs";

export async function GET(request: NextRequest) {
  const token = request.cookies.get(accessCookie)?.value;
  const config = authConfig();
  if (!token || !config) {
    return NextResponse.json({ authenticated: false }, { headers: authHeaders });
  }
  try {
    // Always validate against Supabase Auth. A cookie's presence proves nothing.
    const result = await fetch(new URL("/auth/v1/user", config.url), {
      headers: { apikey: config.key, Authorization: `Bearer ${token}` },
      cache: "no-store",
      signal: AbortSignal.timeout(10000),
    });
    if (!result.ok) return NextResponse.json({ authenticated: false }, { headers: authHeaders });
    const user = await result.json() as { id?: string; email_confirmed_at?: string | null };
    if (!user.id || !user.email_confirmed_at) {
      return NextResponse.json({ authenticated: false }, { headers: authHeaders });
    }
    // A verified Auth identity is NOT permission to access a restricted app account.
    // Account-status authorization is a separate server-side gate, not yet implemented.
    return NextResponse.json({ authenticated: true, accountAccess: "not-verified" }, { headers: authHeaders });
  } catch {
    return NextResponse.json({ authenticated: false }, { status: 503, headers: authHeaders });
  }
}
