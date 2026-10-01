// apple-register-code
//
// Trades Apple's single-use authorization code for a refresh token and parks it
// in apple_tokens, so delete-account can revoke the grant later.
//
// Timing matters: Apple's authorization code is single-use and expires in about
// five minutes, so the app calls this immediately after sign-in rather than
// storing the code for deletion time.
//
// Deploy:  supabase functions deploy apple-register-code

import { createClient } from "jsr:@supabase/supabase-js@2";
import { appleConfigured, exchangeAuthorizationCode } from "../_shared/apple.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Unauthorized" }, 401);

  const asUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await asUser.auth.getUser();
  if (userErr || !user) return json({ error: "Unauthorized" }, 401);

  if (!appleConfigured()) {
    // Not an error the app should act on — it just means the Apple secrets
    // haven't been set yet. Deletion will still work, minus revocation.
    console.warn("Apple secrets not configured; skipping code registration.");
    return json({ stored: false, reason: "apple_not_configured" });
  }

  let code: string | undefined;
  try {
    code = (await req.json())?.authorization_code;
  } catch {
    return json({ error: "Malformed body" }, 400);
  }
  if (!code) return json({ error: "Missing authorization_code" }, 400);

  const refreshToken = await exchangeAuthorizationCode(code);
  if (!refreshToken) return json({ stored: false, reason: "exchange_failed" }, 502);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { error } = await admin
    .from("apple_tokens")
    .upsert(
      { user_id: user.id, refresh_token: refreshToken, updated_at: new Date().toISOString() },
      { onConflict: "user_id" },
    );

  if (error) {
    console.error("apple_tokens upsert failed:", error.message);
    return json({ stored: false, reason: error.message }, 500);
  }

  return json({ stored: true });
});
