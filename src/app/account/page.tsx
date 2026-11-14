"use client";

import Link from "next/link";
import { useEffect, useState } from "react";

export default function AccountPage() {
  const [status, setStatus] = useState<"checking" | "signed-in" | "signed-out" | "error">("checking");

  useEffect(() => {
    let alive = true;
    async function check() {
      try {
        const response = await fetch("/api/auth/session", { cache: "no-store" });
        if (!response.ok) throw Error("Session check unavailable.");
        const result = await response.json() as { authenticated?: boolean };
        if (alive) setStatus(result.authenticated ? "signed-in" : "signed-out");
      } catch { if (alive) setStatus("error"); }
    }
    void check();
    return () => { alive = false; };
  }, []);

  async function logout() {
    try {
      const response = await fetch("/api/auth/logout", { method: "POST", cache: "no-store" });
      if (!response.ok) throw Error("Sign-out failed.");
      setStatus("signed-out");
    } catch { setStatus("error"); }
  }
  return (
    <main id="main-content" className="page-shell">
      <div className="intro">
        <p className="eyebrow">REAL LOVE V2</p>
        <h1>Account</h1>
        {status === "checking" && <p role="status">Checking your session…</p>}
        {status === "error" && <p role="alert">Session service unavailable. Try again.</p>}
        {status === "signed-out" && <p>You are signed out. <Link href="/login">Sign in</Link></p>}
        {status === "signed-in" && <>
          <p>You&apos;re authenticated. Profile onboarding is still being built.</p>
          <button className="auth-action" type="button" onClick={() => { void logout(); }}>Sign out</button>
        </>}
      </div>
    </main>
  );
}
