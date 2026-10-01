// delete-account — App Store Review Guideline 5.1.1(v)
//
// Deletes the caller's account and everything attached to it. A client can
// never delete an auth.users row (that needs the service role key, which must
// never ship in an app), so deletion has to run here.
//
// The caller is identified from their own JWT. A user id in the request body is
// never trusted — that would let anyone delete anyone.
//
// Deploy:  supabase functions deploy delete-account

import { createClient } from "jsr:@supabase/supabase-js@2";
import { appleConfigured, revokeAppleToken } from "../_shared/apple.ts";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// Explicit deletes as well as the ON DELETE CASCADE from the migration. The
// cascade should make these no-ops; if a foreign key is ever missing or renamed,
// this is what stops the rows being orphaned instead of deleted.
//
// The owner column is not `user_id` everywhere: `profiles` keys on `id`, sharing
// the auth user's id in the standard Supabase pattern. Hardcoding user_id here
// would make the profile delete fail silently on every account deletion.
const TABLES: Array<[table: string, ownerColumn: string]> = [
  ["session_letter_stats", "user_id"],
  ["reading_sessions", "user_id"],
  ["letter_stats", "user_id"],
  ["troubled_words", "user_id"],
  ["daily_tasks", "user_id"],
  ["exercise_logs", "user_id"],
  ["conversation_sessions", "user_id"],
  ["journeys", "user_id"],
  ["streaks", "user_id"],
  ["user_awards", "user_id"],
  ["user_goals", "user_id"],
  ["profiles", "id"],
];

const json = (body: unknown, status = 200) =>
  new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });

Deno.serve(async (req) => {
  if (req.method !== "POST") return json({ error: "Method not allowed" }, 405);

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return json({ error: "Unauthorized" }, 401);

  // Identify the caller from their own token.
  const asUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error: userErr } = await asUser.auth.getUser();
  if (userErr || !user) return json({ error: "Unauthorized" }, 401);

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 1. Revoke the Apple grant, if this account has one.
  //
  // Reported back to the client but never fatal: if revocation fails we still
  // delete. Leaving a user with a live account because Apple's endpoint was
  // briefly unavailable is the worse failure, and they asked to be deleted.
  let appleRevoked: boolean | null = null;
  if (appleConfigured()) {
    const { data: row } = await admin
      .from("apple_tokens")
      .select("refresh_token")
      .eq("user_id", user.id)
      .maybeSingle();

    if (row?.refresh_token) {
      appleRevoked = await revokeAppleToken(row.refresh_token);
    }
  }
  await admin.from("apple_tokens").delete().eq("user_id", user.id);

  // 2. Application rows.
  const tableErrors: string[] = [];
  for (const [table, ownerColumn] of TABLES) {
    const { error } = await admin.from(table).delete().eq(ownerColumn, user.id);
    if (error) {
      console.error(`delete ${table}.${ownerColumn}:`, error.message);
      tableErrors.push(table);
    }
  }

  // 3. Storage objects. Deleting an auth user does not touch Storage, so the
  // profile photo would otherwise outlive the account it belongs to — which is
  // the same user-generated content 5.1.1(v) says has to go.
  //
  // The folder is listed rather than the filename assumed, so anything that
  // ever lands in it goes too. Non-fatal for the same reason as the Apple
  // revocation: an orphaned image is not a reason to leave an account alive.
  let storageError: string | null = null;
  try {
    const { data: files, error: listErr } = await admin.storage
      .from("avatars")
      .list(user.id);
    if (listErr) throw listErr;

    const paths = (files ?? [])
      .filter((file) => file.name !== ".emptyFolderPlaceholder")
      .map((file) => `${user.id}/${file.name}`);

    if (paths.length > 0) {
      const { error: removeErr } = await admin.storage.from("avatars").remove(paths);
      if (removeErr) throw removeErr;
    }
  } catch (e) {
    storageError = e instanceof Error ? e.message : String(e);
    console.error("avatar cleanup:", storageError);
  }

  // 4. The auth record. This is the one that must succeed — without it the user
  // can still sign in, which is precisely what 5.1.1(v) forbids.
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) {
    console.error("deleteUser failed:", delErr.message);
    return json({ error: delErr.message, tableErrors, storageError }, 500);
  }

  return json({ deleted: true, appleRevoked, tableErrors, storageError });
});
