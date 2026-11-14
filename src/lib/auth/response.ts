import { NextRequest, NextResponse } from "next/server";

export const authHeaders = {
  "Cache-Control": "no-store",
  "X-Content-Type-Options": "nosniff",
  "Referrer-Policy": "no-referrer",
};

export function authError(message: string, status: number) {
  return NextResponse.json({ error: message }, { status, headers: authHeaders });
}

export function requireSameOrigin(request: NextRequest): boolean {
  const origin = request.headers.get("origin");
  return origin === request.nextUrl.origin && request.headers.get("sec-fetch-site") !== "cross-site";
}

export function authConfig() {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return null;
  try {
    const parsed = new URL(url);
    if (parsed.username || parsed.password || parsed.search || parsed.hash || parsed.pathname !== "/" ||
      (parsed.protocol !== "https:" && !(parsed.protocol === "http:" && ["localhost", "127.0.0.1"].includes(parsed.hostname)))) return null;
    return { url: parsed, key };
  } catch {
    return null;
  }
}

export const accessCookie = "real-love-access";
export const refreshCookie = "real-love-refresh";

export function sessionCookieOptions(request: NextRequest, maxAge: number) {
  return {
    httpOnly: true,
    secure: request.nextUrl.protocol === "https:",
    sameSite: "lax" as const,
    path: "/",
    maxAge,
  };
}
