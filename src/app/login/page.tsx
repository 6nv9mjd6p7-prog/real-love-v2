"use client";

import Link from "next/link";
import { useState, type FormEvent } from "react";

export default function LoginPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [message, setMessage] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    try {
      const response = await fetch("/api/auth/login", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
        cache: "no-store",
      });
      const data = await response.json() as { error?: string };
      if (!response.ok) {
        setError(data.error ?? "Could not sign in.");
        return;
      }
      setPassword("");
      setMessage("Signed in. Account setup is not yet available.");
    } catch {
      setError("Unable to reach the sign-in service.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main id="main-content" className="page-shell">
      <div className="intro">
        <p className="eyebrow">REAL LOVE V2</p>
        <h1>Sign in</h1>
        <form onSubmit={submit} className="auth-form">
          <label htmlFor="login-email">Email address</label>
          <input id="login-email" type="email" autoComplete="email" required
            value={email} onChange={e => setEmail(e.target.value)} />
          <label htmlFor="login-password">Password</label>
          <input id="login-password" type="password" autoComplete="current-password" required
            value={password} onChange={e => setPassword(e.target.value)} />
          <button type="submit" disabled={busy}>{busy ? "Signing in…" : "Sign in"}</button>
        </form>
        {error && <p role="alert" className="form-error">{error}</p>}
        {message && <p role="status" className="form-success">{message}</p>}
        <p><Link href="/register">Create an account</Link></p>
      </div>
    </main>
  );
}
