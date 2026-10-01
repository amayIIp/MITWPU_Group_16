// Shared Apple helpers for the Edge Functions.
//
// Both apple-register-code and delete-account need to authenticate to Apple,
// which is done with a short-lived ES256 JWT signed with the .p8 key from the
// Apple Developer portal (Keys → Sign in with Apple). That JWT is the
// `client_secret` in Apple's token and revoke endpoints.

import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

export const APPLE_CLIENT_ID = Deno.env.get("APPLE_CLIENT_ID") ?? "com.spasht.app";

const APPLE_TEAM_ID = Deno.env.get("APPLE_TEAM_ID")!;
const APPLE_KEY_ID = Deno.env.get("APPLE_KEY_ID")!;
const APPLE_PRIVATE_KEY = Deno.env.get("APPLE_PRIVATE_KEY")!;

/** True when the Apple secrets are configured. Lets callers degrade instead of throwing. */
export function appleConfigured(): boolean {
  return Boolean(APPLE_TEAM_ID && APPLE_KEY_ID && APPLE_PRIVATE_KEY);
}

/**
 * Normalises whatever form the .p8 arrived in into raw base64.
 *
 * The secret can be set from the CLI (`$(cat AuthKey.p8)`, real newlines) or
 * pasted into the dashboard, where newlines sometimes survive as the literal
 * two-character sequence `\n` and the value sometimes arrives wrapped in
 * quotes. A `\s` strip handles the first case only; the rest would reach
 * `atob` as stray characters and fail with an opaque "invalid character"
 * error that says nothing about the real cause.
 */
function normalisePrivateKey(raw: string): string {
  return raw
    .trim()
    .replace(/^["']|["']$/g, "")        // stray wrapping quotes
    .replace(/\\r|\\n/g, "")           // literal backslash-n / backslash-r
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");               // real whitespace and newlines
}

/** Builds the ES256 client_secret JWT Apple expects. Valid for ten minutes. */
export async function appleClientSecret(): Promise<string> {
  const pkcs8 = normalisePrivateKey(APPLE_PRIVATE_KEY);

  let key: CryptoKey;
  try {
    key = await crypto.subtle.importKey(
      "pkcs8",
      Uint8Array.from(atob(pkcs8), (c) => c.charCodeAt(0)),
      { name: "ECDSA", namedCurve: "P-256" },
      false,
      ["sign"],
    );
  } catch (e) {
    // Name the likely cause rather than leaving a base64 error in the logs.
    console.error(
      "APPLE_PRIVATE_KEY could not be parsed. Paste the whole .p8 file including " +
      "the BEGIN/END lines, with no surrounding quotes. Underlying error:",
      e instanceof Error ? e.message : String(e),
    );
    throw e;
  }

  return await create(
    { alg: "ES256", kid: APPLE_KEY_ID, typ: "JWT" },
    {
      iss: APPLE_TEAM_ID,
      iat: getNumericDate(0),
      exp: getNumericDate(60 * 10),
      aud: "https://appleid.apple.com",
      sub: APPLE_CLIENT_ID,
    },
    key,
  );
}

/**
 * Exchanges Apple's single-use authorization code for a refresh token.
 * Returns null on failure — the caller decides whether that is fatal.
 */
export async function exchangeAuthorizationCode(code: string): Promise<string | null> {
  const res = await fetch("https://appleid.apple.com/auth/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: APPLE_CLIENT_ID,
      client_secret: await appleClientSecret(),
      code,
      grant_type: "authorization_code",
    }),
  });

  if (!res.ok) {
    console.error("Apple token exchange failed:", res.status, await res.text());
    return null;
  }

  const body = await res.json();
  return body.refresh_token ?? null;
}

/**
 * Revokes an Apple token grant. Required by Apple when deleting an account
 * that was created with Sign in with Apple.
 *
 * Returns true on success. A failure is logged and reported, but should not by
 * itself abort a deletion the user asked for — losing their data access matters
 * more to them than a stale grant on Apple's side.
 */
export async function revokeAppleToken(refreshToken: string): Promise<boolean> {
  const res = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: APPLE_CLIENT_ID,
      client_secret: await appleClientSecret(),
      token: refreshToken,
      token_type_hint: "refresh_token",
    }),
  });

  if (!res.ok) {
    console.error("Apple revoke failed:", res.status, await res.text());
    return false;
  }
  return true;
}
