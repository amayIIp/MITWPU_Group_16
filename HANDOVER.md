# Spasht — Sign in with Apple handover

For whoever holds the Apple Developer account. Everything in the app is written
and building; what remains needs the account that will actually ship the app.

The portal work is already done — the `.p8`, Key ID and Team ID exist. These are
the steps to connect them.

---

## ⚠️ Two things to reconcile first

Both are one-line changes, and both silently break Sign in with Apple if they
are wrong. Do them before building.

### 1. The bundle identifier does not match the registered App ID

| Where | Value |
|---|---|
| Xcode project right now | `com.spasht.app544` |
| The App ID the capability was enabled on | `com.spasht.app` |
| The Edge Function's `APPLE_CLIENT_ID` default | `com.spasht.app` |

`com.spasht.app544` is left over from development bundle-ID churn. It must become
whatever the App ID actually is — almost certainly `com.spasht.app`.

Why it matters, concretely: Apple puts the bundle ID in the identity token's
`aud` claim, Supabase checks it against its Client IDs list, and the revoke call
signs a `client_secret` with `sub` = bundle ID. Mismatch and sign-in fails, or
sign-in works but account deletion can't revoke the Apple grant — which is the
thing App Review asked for.

**Fix:** Xcode → target **Stuttering App** → General → **Bundle Identifier** →
set to the registered App ID. Both Debug and Release.

> Settle this now. After the first App Store submission the bundle ID is
> permanent.

### 2. The development team is still a personal team

`DEVELOPMENT_TEAM` in the project is `C2N3Q4846H`, which is the developer's own
team, not the account that will ship. Set it to the Team ID that came back with
the `.p8`.

**Fix:** Xcode → target → **Signing & Capabilities** → **Team** → select the
shipping team. That rewrites `DEVELOPMENT_TEAM` for you.

If the Team ID that came back *is* `C2N3Q4846H`, nothing to change here.

---

## Step 1 — Confirm the capability is in the project

Open `Stuttering App.xcodeproj` → target **Stuttering App** → **Signing &
Capabilities**. **Sign in with Apple** should be listed, with no error.

It is already committed: `Stuttering App/Stuttering App.entitlements` declares
`com.apple.developer.applesignin`, and `CODE_SIGN_ENTITLEMENTS` points at it in
both the Debug and Release configurations. Nothing to add — just confirm it
shows without a warning triangle once the team and bundle ID above are right.

If Xcode complains about provisioning, it is holding a stale profile: toggle the
Team dropdown off and back on, or quit and reopen Xcode.

## Step 2 — Supabase: enable the Apple provider

Supabase dashboard → **Authentication → Providers → Apple** → enable.

In **Client IDs**, enter the bundle identifier:

```
com.spasht.app
```

That is all. For a native iOS app you do **not** need the Services ID, the OAuth
secret, or the six-month secret rotation — those are for web sign-in only.

## Step 3 — Supabase: set the three Apple secrets

These are what let account deletion revoke the Apple token, which App Review
requires under Guideline 5.1.1(v).

**No repository, no git, no CLI needed — do this in the browser.**

### In the dashboard

1. [supabase.com/dashboard](https://supabase.com/dashboard) → open the **Spasht**
   project (ref `zolaxhyjzkvupkmogdpo`)
2. **Project Settings** (gear, bottom left) → **Edge Functions** → **Secrets**
   *(the same page is reachable from **Edge Functions** → **Secrets** in the left
   sidebar)*
3. **Add new secret**, once per row:

| Name | Value |
|---|---|
| `APPLE_TEAM_ID` | Team ID from the portal, 10 characters |
| `APPLE_KEY_ID` | Key ID from the key's download page, 10 characters |
| `APPLE_PRIVATE_KEY` | The entire contents of the `.p8` file |

For `APPLE_PRIVATE_KEY`: open `AuthKey_XXXXXXXXXX.p8` in TextEdit or VS Code —
it is a plain text file — select all, and paste. **Include the
`-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines.** Do not add
quotes around it.

Newlines are fine, and so is the dashboard turning them into literal `\n`: the
function normalises both, along with stray wrapping quotes. (Verified against
all four paste shapes.)

4. If the bundle ID is anything other than `com.spasht.app`, add one more:

| Name | Value |
|---|---|
| `APPLE_CLIENT_ID` | the bundle identifier |

Secrets take effect on the next function invocation — **nothing to redeploy**.

### Or, if you prefer the CLI

```bash
supabase secrets set \
  APPLE_TEAM_ID="<Team ID>" \
  APPLE_KEY_ID="<Key ID>" \
  APPLE_PRIVATE_KEY="$(cat /path/to/AuthKey_XXXXXXXXXX.p8)"
```

Check either way with **Secrets** in the dashboard, or `supabase secrets list`.
You should see these alongside `GROQ_API_KEY`.

> Until these are set, `appleConfigured()` returns false: account deletion still
> works, it just skips revoking the Apple grant. So the app is not broken without
> them — it is only incomplete for review.

**Keep the `.p8` out of the repository.** `.gitignore` covers `*.p8`. Storing it
in a password manager is the right home; Apple only lets you download it once.

## Step 4 — Test on a physical device

The simulator cannot do this. It has no Apple Account, so every attempt returns
`ASAuthorizationError 1000`, which the app surfaces as "You're not signed in to
an Apple Account on this device."

| # | Test | What to look for |
|---|---|---|
| 1 | Sign in with Apple, **Share My Email** | Account created, onboarding runs, name shows in Profile |
| 2 | Sign in with Apple, **Hide My Email** | Same, and the address is `@privaterelay.appleid.com` |
| 3 | Sign out, sign back in | Name persists. Apple sends the name *only* on first authorization, so this proves it was stored |
| 4 | Guest → upgrade via Apple | Practice history survives the upgrade |
| 5 | Google, sign out, then Apple on the same email | One account, history intact (identity linking is on) |
| 6 | Delete the account | Then **Settings → [your name] → Sign in with Apple**: Spasht should no longer be listed |

Test 6 is the one that proves revocation works, and it is what makes the reply to
App Review truthful.

> **Order matters for test 6.** Apple's authorization code is single-use and
> expires in about five minutes, so the app hands it to the backend immediately
> after sign-in. An account created *before* Step 3 has no stored refresh token
> and cannot be revoked. Delete any such test account and make a fresh one.

## Step 5 — App Store Connect

- Bundle ID matches the app
- **Privacy Policy URL**: `https://spashtapp.netlify.app/#privacy-policy`
- App Privacy answers match `Stuttering App/PrivacyInfo.xcprivacy` exactly,
  **including Health** — the reasoning is in a comment in that file
- Demo account in App Review Information, email already confirmed
- Screen recording of the full account-deletion flow, captured on a physical
  device, in the Notes field — App Review asked for this explicitly
- Screenshots re-shot from a real build showing the Apple button
- Bump the build number

Then reply on both open review threads. Draft text is in `report.md` §7.

---

## If something fails

| Symptom | Cause |
|---|---|
| Xcode: "Sign in with Apple is not available" | App ID doesn't have the capability, or the wrong team is selected |
| Sign-in returns error 1000 | No Apple Account on the device (or you're on the simulator) |
| Sign-in works, Supabase rejects the token | Bundle ID missing from the Apple provider's **Client IDs** |
| Deletion succeeds but Spasht still appears in iOS Settings | Apple secrets not set, or the account predates Step 3 |
| `supabase functions logs delete-account` shows an Apple revoke failure | Team ID / Key ID / `.p8` don't belong to the same team as the App ID |
| Logs say "APPLE_PRIVATE_KEY could not be parsed" | The secret is truncated or missing the BEGIN/END lines — re-paste the whole file |

Background on every decision behind this is in `report.md` and `PHASES.md`.
