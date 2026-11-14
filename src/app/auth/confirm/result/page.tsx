import Link from "next/link";

export default function ConfirmationResultPage() {
  return (
    <main id="main-content" className="page-shell">
      <div className="intro">
        <p className="eyebrow">REAL LOVE V2</p>
        <h1>Email confirmation unsuccessful</h1>
        <p>The link may have expired or already been used. You can request a new confirmation email after signing in is available.</p>
        <p><Link href="/">Back to Real Love</Link></p>
      </div>
    </main>
  );
}
