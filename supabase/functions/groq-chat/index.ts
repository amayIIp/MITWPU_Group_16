// groq-chat — proxies Groq so the API key stops shipping inside the app.
//
// Before this, GroqService held the key as a Swift string constant, which meant
// it was recoverable from the shipped IPA with `strings`. Anyone could then bill
// inference to the account. The key now lives only here, as a function secret.
//
// Authenticated callers only (decision D6). The AI features are account-only in
// the app — guest mode is local-only and its AI paths fall back to rule-based
// text — so this function requires a real user token and has no anonymous path.
// That makes it a closed proxy rather than a metered open one.
//
// Deploy:  supabase functions deploy groq-chat
//          (verify_jwt stays ON — do NOT pass --no-verify-jwt)

import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const GROQ_API_KEY = Deno.env.get("GROQ_API_KEY")!;

const GROQ_URL = "https://api.groq.com/openai/v1/chat/completions";
const MODEL = "llama-3.3-70b-versatile";

// Generous enough for real use, tight enough that a compromised account
// can't run up an unbounded bill.
const LIMIT_USER = 120;
const WINDOW = "1 hour";

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  // ── Identify the caller ──────────────────────────────────────────────────
  // No anonymous path: an unauthenticated request is refused outright.
  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Unauthorized" }, 401);

  const asUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await asUser.auth.getUser();
  if (userErr || !user) return json({ error: "Unauthorized" }, 401);

  let payload: {
    messages?: Array<{ role: string; content: string }>;
    max_tokens?: number;
    temperature?: number;
  };
  try {
    payload = await req.json();
  } catch {
    return json({ error: "Malformed body" }, 400);
  }

  const messages = payload.messages;
  if (!Array.isArray(messages) || messages.length === 0) {
    return json({ error: "Missing messages" }, 400);
  }

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);
  const { data: allowed, error: rateErr } = await admin.rpc("ai_usage_allow", {
    p_bucket: `user:${user.id}`,
    p_limit: LIMIT_USER,
    p_window: WINDOW,
  });

  if (rateErr) {
    // Fail open on a counter failure: the AI features are all optional
    // enhancements with rule-based fallbacks, and breaking them because a
    // counter table hiccuped is worse than briefly missing a limit.
    console.error("rate limit check failed:", rateErr.message);
  } else if (allowed === false) {
    return json({ error: "Rate limit exceeded" }, 429);
  }

  // ── Forward to Groq ──────────────────────────────────────────────────────
  const groqRes = await fetch(GROQ_URL, {
    method: "POST",
    headers: {
      Authorization: `Bearer ${GROQ_API_KEY}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      model: MODEL,
      messages,
      temperature: payload.temperature ?? 0.7,
      max_tokens: Math.min(payload.max_tokens ?? 200, 1024),
    }),
  });

  const body = await groqRes.text();
  return new Response(body, {
    status: groqRes.status,
    headers: { "Content-Type": "application/json" },
  });
});
