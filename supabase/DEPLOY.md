# Deploying the Supabase backend

One-time setup, then three function deploys and two migrations.

Project ref: **`zolaxhyjzkvupkmogdpo`** (from the URL in `SupabaseManager.swift`).

---

## 1. Install the CLI

```bash
brew install supabase/tap/supabase
```

Check it:

```bash
supabase --version
```

## 2. Log in

```bash
supabase login
```

Opens a browser, asks you to authorise, drops a token on this machine. Once per machine.

## 3. Initialise and link

From the repo root:

```bash
supabase init
```

This creates `supabase/config.toml`. It will **not** touch the `functions/` and `migrations/` folders that are already there — it only adds the config file. If it complains the project is already initialised, that's fine, skip it.

Then link this folder to your hosted project:

```bash
supabase link --project-ref zolaxhyjzkvupkmogdpo
```

It asks for your **database password** — the one set when the project was created, under Project Settings → Database if you need to reset it.

## 4. Run the migrations

```bash
supabase db push
```

This applies both files in `migrations/`:

- `20260918000100_account_deletion.sql` — `ON DELETE CASCADE` on all 12 tables, plus the `apple_tokens` table
- `20260918000200_groq_proxy.sql` — the `ai_usage` rate-limit table and its function

**Check the result before moving on.** The first migration drops whatever foreign key currently sits on each `user_id` column and replaces it, so confirm the constraints came out right:

```sql
select conrelid::regclass as table_name, conname, confdeltype
from pg_constraint
where contype = 'f' and confrelid = 'auth.users'::regclass
order by 1;
```

`confdeltype` should be `c` (cascade) on all 12 rows.

## 5. Set the secrets

```bash
supabase secrets set \
  GROQ_API_KEY="gsk_..." \
  APPLE_TEAM_ID="C2N3Q4846H" \
  APPLE_KEY_ID="..." \
  APPLE_PRIVATE_KEY="$(cat ~/Downloads/AuthKey_XXXXXXXXXX.p8)"
```

- `GROQ_API_KEY` — from the Groq console
- `APPLE_KEY_ID` and the `.p8` — from the Sign in with Apple key you create in the Apple Developer portal (Phase 1). **If you haven't done that step yet, deploy without the three Apple values** — `apple-register-code` and the revocation half of `delete-account` degrade gracefully when the Apple secrets are missing, and deletion still works. Add them later and re-run this command.

Check what's set:

```bash
supabase secrets list
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are injected automatically — you do not set those.

## 6. Deploy the functions

```bash
supabase functions deploy delete-account
supabase functions deploy apple-register-code
supabase functions deploy groq-chat
```

> ⚠️ **Do not pass `--no-verify-jwt`.** An earlier version of the plan said to, back when the AI features were available to guests. Decision D6 made them account-only, so all three functions require a real user token and the default (`verify_jwt` on) is correct. Passing the flag would make `groq-chat` an open proxy to your Groq billing.

`groq-chat` imports nothing shared. `delete-account` and `apple-register-code` both import `../_shared/apple.ts`; the CLI bundles that automatically, no extra step.

## 7. Verify

```bash
supabase functions list
```

All three should show as deployed. Then, from the app on a device:

| Check | How |
|---|---|
| `groq-chat` | Sign in, finish a reading session — the post-session insight should read like written prose, not a template. Guests get the template, by design |
| `delete-account` | Settings → Delete Account, then confirm zero rows for that `user_id` in Supabase |
| `apple-register-code` | Sign in with Apple, then check `apple_tokens` has a row for that user |

Logs for a failing call:

```bash
supabase functions logs delete-account
```

---

## Troubleshooting

**`supabase link` fails with a password error.** Reset the database password under Project Settings → Database. It is not your Supabase account password.

**A function deploys but returns 401.** The app is sending an expired or missing session token. Sign out and back in.

**`delete-account` returns 500.** Check `supabase functions logs delete-account`. Most likely the service role key isn't reaching it, or a table name in `TABLES` doesn't match your schema.

**`groq-chat` returns 429.** The rate limit — 120 requests per user per hour. Change `LIMIT_USER` in the function and redeploy.

**Apple revocation silently skipped.** Expected when the Apple secrets aren't set; `appleConfigured()` returns false and deletion proceeds without revoking. Set the secrets and re-test.
