import { NextRequest, NextResponse } from "next/server";

export const runtime = "nodejs";

function redirect(request: NextRequest, status: "success" | "error") {
  const destination = new URL(status === "success" ? "/login?verified=1" : "/auth/confirm/result?status=error", request.nextUrl.origin);
  const response = NextResponse.redirect(destination, 303);
  response.headers.set("Cache-Control", "no-store");
  response.headers.set("Referrer-Policy", "no-referrer");
  return response;
}

export async function POST(request: NextRequest) {
  const origin = request.headers.get("origin");
  if (!origin || origin !== request.nextUrl.origin ||
      request.headers.get("sec-fetch-site") === "cross-site") {
    return new NextResponse("Forbidden", { status: 403, headers: { "Cache-Control": "no-store" } });
  }
  if (!request.headers.get("content-type")?.startsWith("application/x-www-form-urlencoded")) {
    return new NextResponse("Unsupported content type", { status: 415 });
  }

  const body = await request.text();
  if (body.length > 2048) return new NextResponse("Request too large", { status: 413 });
  const values = new URLSearchParams(body);
  const tokenHash = values.get("token_hash");
  if (values.get("type") !== "email" || !tokenHash || !/^[a-f0-9]{32,128}$/i.test(tokenHash)) {
    return redirect(request, "error");
  }
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) return new NextResponse("Verification unavailable", { status: 503 });
  try {
    const base = new URL(url);
    if (base.username || base.password || base.search || base.hash || base.pathname !== "/" ||
        (base.protocol !== "https:" &&
         !(base.protocol === "http:" && ["localhost", "127.0.0.1"].includes(base.hostname)))) {
      return new NextResponse("Verification unavailable", { status: 503 });
    }
    const response = await fetch(new URL("/auth/v1/verify", base), {
      method: "POST",
      headers: { apikey: key, "Content-Type": "application/json" },
      body: JSON.stringify({ type: "email", token_hash: tokenHash }),
      cache: "no-store",
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) return redirect(request, "error");
    // Supabase can return a session. Do not expose it or create a cookie here.
    // Login and session handling will be implemented as a separate verified flow.
    return redirect(request, "success");
  } catch {
    return new NextResponse("Verification temporarily unavailable", { status: 503 });
  }
}
