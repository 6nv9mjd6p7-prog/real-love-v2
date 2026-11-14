import { readFileSync, existsSync } from 'node:fs';
const path = '.env.local';
if (!existsSync(path)) {
  console.error('Missing .env.local; copy .env.example and fill in the actual local CLI key.');
  process.exit(1);
}
const env = Object.fromEntries(readFileSync(path, 'utf8').split(/\r?\n/).filter(x => x.trim() && !x.trim().startsWith('#')).map(line => {
  const idx = line.indexOf('=');
  return idx < 0 ? [line.trim(), ''] : [line.slice(0,idx).trim(),line.slice(idx+1).trim().replace(/^['"]|['"]$/g,'')];
}));
const url = env.NEXT_PUBLIC_SUPABASE_URL;
const key = env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
if (!url || !key || /REPLACE_WITH/.test(key)) throw Error('Set actual local Supabase URL and publishable key from supabase status.');
const host = new URL(url).hostname;
if (!['localhost','127.0.0.1','::1','[::1]'].includes(host)) throw Error('V2 Phase A only permits loopback local Supabase URLs.');
if (Object.keys(env).some(k => k.startsWith('NEXT_PUBLIC_') && /SERVICE_ROLE|SECRET|PASSWORD|PRIVATE/i.test(k))) throw Error('Privileged key exposed in public environment variable name.');
console.log('Local Supabase environment guard passed.');
