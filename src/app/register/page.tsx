"use client";

import Link from "next/link";

import { useState, type FormEvent } from "react";

type Result = { error?: string; message?: string };

export default function RegistrationPage() {
  const [email, setEmail] = useState("");
  const [password, setPassword] = useState("");
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState("");

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    if (busy) return;
    setBusy(true);
    setError("");
    setMessage("");
    try {
      const response = await fetch("/api/auth/register", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ email, password }),
        cache: "no-store",
      });
      const data = await response.json() as Result;
      if (!response.ok) throw new Error(data.error ?? "Registration failed.");
      setMessage(data.message ?? "Check your email to verify your account.");
      setPassword("");
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : "Registration failed.");
    } finally {
      setBusy(false);
    }
  }

  return (
    <main id="main-content" className="page-shell">
      <div className="intro">
        <p className="eyebrow">REAL LOVE V2</p>
        <h1>Create an account</h1>
        <p>Start with your email. You&apos;ll build your profile after verification.</p>
        <form onSubmit={submit} className="auth-form">
          <label htmlFor="registration-email">Email address</label>
          <input id="registration-email" type="email" autoComplete="email"
            required maxLength={254} value={email} onChange={e => setEmail(e.target.value)} />
          <label htmlFor="registration-password">Password</label>
          <input id="registration-password" type="password" autoComplete="new-password"
            required minLength={12} maxLength={128}
            value={password} onChange={e => setPassword(e.target.value)} />
          <p className="form-help">Use at least 12 characters.</p>
          <button type="submit" disabled={busy}>{busy ? "Creating account…" : "Create account"}</button>
        </form>
        {error && <p role="alert" className="form-error">{error}</p>}
        {message && <p role="status" className="form-success">{message}</p>}
        <p><Link href="/">Back to Real Love</Link></p>
      </div>
    </main>
  );
}
