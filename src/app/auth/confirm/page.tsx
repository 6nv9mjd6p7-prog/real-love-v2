import Link from "next/link";

export const dynamic = "force-dynamic";

export default async function ConfirmEmailPage({
  searchParams,
}: {
  searchParams: Promise<{ token_hash?: string; type?: string }>;
}) {
  const { token_hash: tokenHash, type } = await searchParams;
  const valid = typeof tokenHash === "string" && /^[a-f0-9]{32,128}$/i.test(tokenHash) && type === "email";
  return (
    <main id="main-content" className="page-shell">
      <div className="intro">
        <p className="eyebrow">REAL LOVE V2</p>
        <h1>Confirm your email</h1>
        {valid ? (
          <>
            <p>Complete email verification to continue setting up your account.</p>
            <form action="/api/auth/confirm" method="post" className="auth-form">
              <input type="hidden" name="token_hash" value={tokenHash} />
              <input type="hidden" name="type" value="email" />
              <button type="submit">Confirm email</button>
            </form>
          </>
        ) : (
          <p>This confirmation link is invalid. Request a fresh confirmation email.</p>
        )}
        <p><Link href="/">Back to Real Love</Link></p>
      </div>
    </main>
  );
}
