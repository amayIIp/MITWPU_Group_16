# Spasht — App Store Resubmission Plan

Execution plan for the findings in [report.md](report.md). Sequenced by **dependency**, not by severity — the report ranks by urgency, this ranks by what unblocks what.

**Estimate:** 8–11 working days for one developer, assuming the privacy policy is written in parallel by someone else. Phases 2 and 3 can overlap if two people are working.

---

## Decision gates

Five things need answers. Each blocks a specific phase, so resolve them at or before the phase that needs them — not all up front.

| # | Question | Blocks | Needed by |
|---|----------|--------|-----------|
| D1 | Is RLS enabled on all 12 Supabase tables? | — | ✅ **Confirmed on, 18 Sep 2026** |
| D2 | Email verification | — | ✅ **Enabled, 18 Sep 2026** |
| D3 | Who writes the privacy policy and terms, and by when? | Phase 4, and it's the longest lead time | Phase 1 |
| D4 | Apple + Google on the same email — link or fork? | — | ✅ **Link**, 18 Sep 2026 |
| D5 | Does the 464 MB Whisper model still need to ship? | Phase 5 scope | Phase 5 |
| D6 | Should guests keep AI features? | — | ✅ **No — account-only**, implemented 18 Sep 2026 |

---

## Phase 0 — Contain the secrets

**Goal:** Nothing sensitive is exposed or exposable before any other work starts.
**Blocked by:** nothing. Do this today.
**Status:** code work done 18 Sep 2026 (build verified). **Three revocations and D1 are outstanding and are yours to do.**

> ### 🔴 Live exposure — found 18 Sep 2026
>
> The report assumed the keys had never been committed. They had. Three distinct
> keys are reachable from `origin/main` on **<https://github.com/amayIIp/MITWPU_Group_16>,
> which is a public repository**, and have been since **11 May 2026**:
>
> | Key | Where | Status |
> |-----|-------|--------|
> | `AIzaSyAMIz…f4Bm4` | Gemini — was live in `AppSecrets.swift` **and** in history | 🔴 Public since 11 May |
> | `AIzaSyCfny…vSEV0` | Gemini — older key, history only | 🔴 Public since 4 May |
> | `gsk_eoXIZL7f…0cLWNv` | Groq — older key, history only | 🔴 Public since 11 May |
> | `gsk_PbsHcT1t…FnVNkc` | Groq — current, working tree only | 🟡 Not in history; ships in the IPA at release → Phase 3 |
> | `gsk_QSmC7SBG…` | Groq — commented-out, working tree only | ⚪️ Dead, deleted |
> | `sb_publishable_kqZY…aYKP` | Supabase | ⚪️ Public by design — safe *only* if D1 passes |
>
> Leaking commits: `3e6f5bc`, `ae10ef5`, `e24bbfb`, `40ab67f` — all on `origin/main`,
> plus `developerssss`, `newsupabase`, `upload-to-drive`. Commit `40ab67f` ("App Secrets")
> moved the keys out of `GeminiService.swift` and `GroqService.swift` into
> `AppSecrets.swift`, but moving a secret in a later commit does not remove it from
> history — the earlier commits still carry it.
>
> GitHub is scraped continuously for API keys. Four months of public exposure means
> **assume all three are compromised.** Rotation is remediation, not precaution.

### Done in the repo
- [x] `.gitignore` fixed — now matches `AppSecrets.swift` anywhere in the tree, with `!AppSecrets.example.swift` negated. The old rules named two specific paths and the file lived at a third
- [x] `geminiAPIKey` deleted — nothing in the app referenced it
- [x] Dead commented-out Groq key deleted
- [x] `AppSecrets.example.swift` added, with a header explaining that anything in this file is world-readable once shipped
- [x] Example file added to `membershipExceptions` in `project.pbxproj` — without this the synchronized folder compiles it and `struct AppSecrets` collides
- [x] README setup step rewritten around the template
- [x] `git check-ignore` confirms the real file ignored, example file tracked
- [x] **Build verified** — `** BUILD SUCCEEDED **`

### Yours to do — outside the repo
- [ ] **Revoke `AIzaSyAMIz…f4Bm4`** — Google Cloud Console → APIs & Services → Credentials. No replacement needed; the app doesn't use Gemini
- [ ] **Revoke `AIzaSyCfny…vSEV0`** — same place
- [ ] **Revoke `gsk_eoXIZL7f…0cLWNv`** — Groq console → API Keys
- [x] Consoles checked — no unexpected usage, 18 Sep 2026
- [ ] Rotate `gsk_PbsHcT…` too. It isn't publicly leaked, but it has been passed around in plaintext, and Phase 3 removes it from the app entirely anyway
- [x] Repo stays **public** — decided 18 Sep 2026. See the accepted-risk note below
- [x] **D1: RLS confirmed enabled on all tables** — 18 Sep 2026

### Accepted risk — recorded 18 Sep 2026

Rotation was **declined** and the repo **stays public**. Usage on both consoles
was checked and showed nothing unexpected.

So the standing position is: three keys remain live and publicly readable in
`origin/main`'s history. Two of them (`AIzaSyAMIz…`, `AIzaSyCfny…`) are Gemini
keys the app no longer uses at all, and `gsk_eoXIZL7f…` is a superseded Groq
key — so revoking all three would cost nothing functionally, whenever you want
to. Recorded here so the decision is visible rather than forgotten.

### Purging history — a judgement call
Rewriting history with `git filter-repo` removes the keys from the repo, but **not** from
GitHub's fork network, pull-request refs, or anyone's existing clone, and it breaks every
open branch and PR for your teammates. Given this is a university group project with six
remote branches and merged PRs:

**Recommended:** revoke the keys (which makes the leaked strings worthless), leave history
alone, and make the repo **private** if it doesn't need to be public. Revocation is the
control that actually matters; history rewriting is cosmetic once the keys are dead.

**Only rewrite if** a grader or reviewer will read the history and you need it clean. If so,
coordinate with everyone first — all branches must be re-cloned afterwards.

**Exit criteria:** The three leaked keys are revoked and confirmed dead. RLS confirmed on all 12 tables.

> ⚠️ If D1 comes back false on any table, **stop and fix it before anything else.** A publishable key plus RLS-off means every user's speech-practice history is world-readable — and unlike the provider keys, that one exposes your users rather than your billing.

> Note: this phase only *rotates* the Groq key. Moving it out of the binary is Phase 3, because it needs the Edge Function infrastructure built there.

---

## Phase 1 — Groundwork and long-lead items

**Goal:** Every external dependency is in place so no later phase stalls waiting on a portal, a key, or a lawyer.
**Blocked by:** Phase 0.
**Status:** repo-side work done 18 Sep 2026 (build verified). **The portal and dashboard steps are yours — they need your credentials.**

### Done in the repo
- [x] `Stuttering App/Stuttering App.entitlements` created with `com.apple.developer.applesignin = [Default]`
- [x] `CODE_SIGN_ENTITLEMENTS` wired into **both** the Debug and Release configurations of the app target
- [x] Entitlements file added to `membershipExceptions` so the synchronized folder doesn't copy it into the bundle, the way `Info.plist` already is
- [x] **Build verified** — `** BUILD SUCCEEDED **`
- [x] **D3 drafted** — [docs/PRIVACY.md](docs/PRIVACY.md) and [docs/TERMS.md](docs/TERMS.md), with every factual claim checked against the source. Status and remaining blanks in [docs/README.md](docs/README.md)

> ⚠️ **Order matters.** The entitlement is now in the project, but the App ID does not have the capability yet. Until you do the portal step below, **automatic signing for a physical device will fail** with a provisioning-profile error. Simulator builds are unaffected. Do the portal step before your next device build.

### Apple Developer portal
- [ ] Identifiers → `com.spasht.app1` → enable **Sign in with Apple** → Save
- [ ] Keys → **+** → tick Sign in with Apple → Configure → primary App ID `com.spasht.app1` → Register
- [ ] **Download the `.p8` — Apple allows this once and only once.** Store it in your password manager, not the repo
- [ ] Record the **Key ID** and **Team ID** (`C2N3Q4846H`) alongside it
- [ ] Services → Sign in with Apple for Email Communication → register your sending domain (otherwise Private Relay users never receive password-reset mail)

### Xcode
- [x] ~~Target → Signing & Capabilities → + Capability → Sign in with Apple~~ — done by hand; the entitlements file and both `CODE_SIGN_ENTITLEMENTS` entries are in place
- [ ] After the portal step above, open Signing & Capabilities and confirm **Sign in with Apple** shows with no error, and that a device build signs cleanly

### Supabase
- [ ] Authentication → Providers → **Apple** → enable → Client IDs = `com.spasht.app1` (native-only: no Services ID, no OAuth secret, no 6-month rotation)
- [x] **D2: email confirmation enabled** — 18 Sep 2026. The app already handles the confirmation-pending path (resend + go to sign-in), added in Phase 5
- [x] **D4: identity linking enabled** — 18 Sep 2026
- [x] Supabase CLI installed and project linked — 18 Sep 2026

### Parallel track — privacy policy and terms
- [x] **D3 drafted** — see [docs/README.md](docs/README.md) for status. The factual claims are checked against the code; the legal shape is not
- [ ] Fill the blanks listed in `docs/README.md` (entity name, contact emails, Supabase region, Groq retention terms, jurisdiction)
- [ ] **Decide the minimum age.** Stuttering commonly begins in childhood, so under-18 users are a realistic audience. This decision propagates to the terms, the privacy policy, the App Store age rating, and possibly a parental-consent flow — it is the most consequential open question in the drafts
- [ ] Legal review, particularly children's data, lawful basis, and the liability/governing-law sections
- [ ] Host both and get the URLs — Phase 4 links to them from Settings, and App Store Connect requires the privacy policy URL

**Exit criteria:** `.p8` safely stored, Sign in with Apple enabled on the App ID and confirmed in Xcode, Supabase Apple provider enabled, D2 and D4 answered, legal drafts in review with a delivery date.

---

## Phase 2 — Sign in with Apple (Guideline 4.8)

**Goal:** Apple rejection #1 closed.
**Blocked by:** Phase 1 portal + Supabase config. Needs **D4** answered.
**Status:** code complete 18 Sep 2026, verified as far as a simulator allows. **The end-to-end account tests below need a real Apple Account.**

### Done in the repo
- [x] `Stuttering App/Model/Networking/AppleSignInManager.swift` added
- [x] `completeSignIn(userId:)` extracted in `LoginViewController` — the email and Google paths were byte-for-byte duplicates; Apple would have made three
- [x] `completeSignUp(userId:displayName:)` extracted in `SignUpViewController`. Note this is **not** the same routine as login's: sign-up *pushes* local data to the cloud, login *pulls* it down
- [x] `appleSignInTapped` wired into both view controllers
- [x] Apple's one-time `fullName` persisted to the local profile and to Supabase user metadata, without overwriting a name the user already has
- [x] `.cancelled` handled silently on both screens
- [x] Apple button installed **programmatically** into the stack view that already holds the Google button, one position above it, matching its height and capsule corner radius — no storyboard surgery, and it can't drift out of alignment with the Google button's styling
- [x] `AccountDeletionService.registerAppleAuthorizationCode(_:)` stubbed for Phase 3
- [x] **Build verified** — `** BUILD SUCCEEDED **`, no concurrency warnings

### Verified in the simulator (iPhone 17 Pro, iOS 26)
- [x] Apple button renders on **both** Sign In and Create Account, full width, same height as Google, directly above it
- [x] Tapping it runs the whole chain — handler → `AppleSignInManager.signIn` → `ASAuthorizationController` → delegate → error surfaced on the right screen with the right alert title
- [x] Apple's error codes mapped to readable messages instead of `AuthorizationError error 1000`

> ### Two things the simulator run caught
>
> **1. `addTarget` does not fire on `ASAuthorizationAppleIDButton` under iOS 26.**
> This is the documented way to handle that button, and it is what the plan in
> report.md §3.4 specified. On the simulator it produced *nothing at all* — no
> handler, no overlay, no error — while an identical tap on the Google button
> 65pt below worked normally. A `UITapGestureRecognizer` on the same button
> fires correctly. Both are now attached, with a re-entrancy guard in `signIn`
> so a double trigger can't start two authorizations. **Had this shipped on
> target-action alone, the Apple button would have been dead on arrival and the
> 4.8 rejection would have repeated** — with the button plainly visible in the
> screenshots, which is the worst version of that outcome.
>
> **2. Raw Apple errors are unreadable.** The first working tap produced "The
> operation couldn't be completed. (com.apple.AuthenticationServices.
> AuthorizationError error 1000.)". Now mapped per code, including the
> signed-out case — which is exactly what a reviewer hits on a device that
> isn't signed in to an Apple Account.

### Verify on a physical device
- [ ] Sign in with Apple, **Share My Email** → account created, onboarding runs, name appears in Profile
- [ ] Sign in with Apple, **Hide My Email** → same, and the email is `@privaterelay.appleid.com`
- [ ] Sign out, sign back in → session restores, name persists, cloud data syncs back
- [ ] Guest → upgrade via Apple → guest data migrates (`migrateGuestData`)
- [ ] **D4 behaviour:** sign in with Google, sign out, sign in with Apple on the same email → confirm it does what you decided
- [ ] Apple button is not smaller, narrower, or lower-contrast than Google's

**Exit criteria:** An Apple account is indistinguishable in capability from a Google or email account — same onboarding, same sync, same data. Equal-or-better button prominence is the single most common cause of a repeat 4.8 rejection, so check it against a screenshot.

---

## Phase 3 — Account deletion (Guideline 5.1.1(v))

**Goal:** Apple rejection #2 closed, and the Groq key out of the binary while the Edge Function scaffolding is fresh.
**Blocked by:** Phase 1 `.p8`. Revocation can't be tested until Phase 2 ships.
**Status:** code complete 18 Sep 2026, guest path verified end to end in the simulator. **Migrations and function deploys are yours.**

### Done in the repo
- [x] `supabase/migrations/20260918000100_account_deletion.sql` — `ON DELETE CASCADE` to `auth.users` on all 12 tables, plus the `apple_tokens` table (RLS on, **no policies** — service-role only by design)
- [x] `supabase/migrations/20260918000200_groq_proxy.sql` — `ai_usage` table and an atomic `ai_usage_allow()` rate-limit function
- [x] `supabase/functions/delete-account` — revoke Apple token → delete 12 tables → `auth.admin.deleteUser`, caller identified from their own JWT
- [x] `supabase/functions/apple-register-code` — exchanges Apple's code for a refresh token
- [x] `supabase/functions/groq-chat` — the proxy
- [x] `supabase/functions/_shared/apple.ts` — ES256 `client_secret` signing, token exchange, revocation
- [x] `AccountDeletionService` — cloud call first, then local teardown
- [x] `AccountDeletionFlow` — one confirm → delete → confirm implementation, two entry points
- [x] `GroqService` routed through `groq-chat`; **`groqAPIKey` deleted from the app entirely**
- [x] `NotificationManager.cancelAllNotifications()` added
- [x] `session.deviceId` cleared on deletion (`endSession()` preserves it, which is right for sign-out and wrong here)
- [x] Loose `.m4a` / `.mov` / `.wav` / `.caf` files swept from Documents
- [x] Delete Account button in the Settings footer, beneath Log Out
- [x] **Build verified** — `** BUILD SUCCEEDED **`

### Verified in the simulator (guest path, end to end)
- [x] Entry point visible, confirm → type DELETE → "Account Deleted" → returns to landing
- [x] `session.deviceId` **gone** from preferences afterwards; `session.userMode` back to `none`; login and onboarding flags cleared
- [x] All three SQLite databases reset; no media files left in Documents

> ### What the simulator run caught: guests could not reach deletion at all
>
> The plan put Delete Account in Settings. But `HomePageViewController.profileTapped`
> only opens Settings when `isAccountMode` — **guests are sent to the sign-up sheet
> instead and can never reach the Settings screen.** So the guest deletion path,
> which Apple's guidance explicitly requires for automatically generated accounts,
> was built and wired and completely unreachable.
>
> Fixed by extracting the flow into `AccountDeletionFlow` and giving it a second
> entry point on the sheet guests actually see, in the slot left by the
> "Continue as Guest" button that is already hidden in guest mode. Account holders
> see no change.
>
> **This is worth revisiting as a product question.** A red "Delete All My Data" on
> a *Create Account* screen is defensible and reachable in two taps, but it is an
> odd home for it. The cleaner fix is to let guests into a real Settings screen —
> which needs Profile, Summary and Set Goals checked for guest-mode behaviour
> first, so it was out of scope here.

> ### D6 decided: AI features are account-only
>
> Implemented 18 Sep 2026. `GroqService.isAvailable` returns false in guest mode
> and every entry point guards on it, so the `groq-chat` function requires a real
> user token and has no anonymous path — a closed proxy, not a metered open one.
>
> Degradation is clean because every Groq call site already had a fallback: the
> insight engine writes its own text, and the paragraph generator still has
> on-device Foundation Models plus a rule-based tier. Conversation practice is the
> exception — its fallback is an apology loop — so it is gated at the screen with
> a "needs an account" prompt that offers sign-up, in `VoiceViewController`
> rather than on the home card, because the tab bar reaches it directly.
>
> A side effect worth having: guest mode is now genuinely local-only, which is
> what the README claimed all along and was not true until now.

> ### Two documentation claims corrected
>
> Tracing the Groq calls showed the README's "Guest mode completely disables all
> network traffic" is **false** — guests send session metrics and conversation
> transcripts to Groq. Both the README and the draft privacy policy have been
> corrected. Worth knowing before it appeared in a published privacy policy.

### Yours to do
- [x] Both migrations applied and verified — 18 Sep 2026
- [x] `delete-account` deployed — 18 Sep 2026
- [x] `apple-register-code` deployed — 18 Sep 2026
- [x] `groq-chat` deployed with `verify_jwt` on — 18 Sep 2026
- [x] `GROQ_API_KEY` set — 18 Sep 2026
- [ ] **Still to set after tomorrow's portal work:** `supabase secrets set APPLE_TEAM_ID="C2N3Q4846H" APPLE_KEY_ID="…" APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"` — until then Apple token revocation is skipped and deletion proceeds without it
- [x] Schema mismatch found and fixed — see the note below
- [ ] Verify guests can still use conversation practice after the proxy goes live

> ### The migration failed first time — `profiles` doesn't key on `user_id`
>
> Both the migration and `delete-account` assumed all 12 tables key on `user_id`.
> They don't: **`profiles` keys on `id`**, sharing the auth user's id in the
> standard Supabase pattern — which is how the app itself queries it
> (`SupabaseSyncManager.swift:271`, `.eq("id", userId)`). The first `db push`
> aborted on the very first table and rolled back cleanly, nothing applied.
>
> Worth noting what would have happened if only the migration had been fixed:
> `delete-account` had the same wrong assumption, and a `.eq("user_id", …)`
> against `profiles` fails as an error the loop only logs. Deletion would have
> reported success while **leaving every user's profile row behind** — name,
> phone number, onboarding state — which is precisely the 5.1.1(v) failure Apple
> rejected on. Both are now driven from an explicit (table, column) map.
>
> The migration also now skips a missing table or column with a notice instead
> of aborting, so future schema drift surfaces as a warning rather than a
> half-applied push.

### Verify on a physical device
- [ ] Seed a full account: onboarding, one reading session, one Story Cube recording, one video diary entry, one award
- [ ] Confirm rows exist across all relevant tables
- [ ] Delete → **zero** rows for that `user_id` in all 12 tables, `auth.users` row gone
- [ ] Signing back in with the same credentials fails
- [ ] Documents directory has no orphaned media
- [ ] With a SIWA account: after deletion, **Settings → [name] → Sign in with Apple** no longer lists Spasht. This is the visible proof revocation worked
- [ ] Guest deletion wipes local data and returns to landing

**Exit criteria:** Deletion is reachable in ≤3 taps from home, removes everything in the §4.2 table, and revocation is confirmed in iOS Settings.

> If revocation plumbing can't land in time, ship deletion **without** it rather than shipping no deletion — deletion is what Apple rejected on. But treat it as required, not optional: it's written into Apple's own account-deletion requirements and reviewers cite it.

---

## Phase 4 — Compliance surface

**Goal:** Everything else a reviewer checks against the guidelines.
**Blocked by:** privacy policy URLs from **D3** — everything else was independent.
**Status:** code complete 18 Sep 2026. Debug and Release both build. **The real legal URLs are still needed.**

### Done in the repo
- [x] **`MockHomeScreen.swift` deleted**, along with **two** call sites — the `AppDelegate` hook the report found, and a second `applyMockHomeDataIfNeeded()` in `HomePageViewController.viewWillAppear` that it missed
- [x] `SessionDiagnosticsViewController` long-press gated behind `#if DEBUG` — both the gesture setup and the handler, so the selector isn't compiled into Release at all
- [x] Lorem ipsum cleared from `Reading.storyboard` and `Conversation.storyboard`
- [x] `LegalLinks` added — URLs, the disclaimer text, `SFSafariViewController` presentation, and the shared "Privacy Policy · Terms · Support" row
- [x] Link row added to the **settings footer** and to the **sign-up sheet**
- [x] Medical disclaimer shown once on first reaching Home, acknowledged with "I Understand", plus `AppState.hasSeenMedicalDisclaimer`
- [x] Purpose strings rewritten for camera, microphone and speech recognition
- [x] `NSPrivacyCollectedDataTypes` added — email, name, phone, user ID, other user content, product interaction
- [x] `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` in both configurations
- [x] Empty `<key></key>` removed from `Info.plist`; empty `UIStatusBarStyle` removed from both configurations
- [x] **Build verified** — Debug and Release

### Verified in the simulator
- [x] Disclaimer appears on first launch and not on later ones

> ### Three things this phase turned up
>
> **1. A second MockHome call site.** The report found the `AppDelegate` hook.
> There was also `applyMockHomeDataIfNeeded()` in `HomePageViewController`.
> Deleting only the first would have left the file referenced and the build broken —
> or, worse, left the hook in if the file had been kept.
>
> **2. The disclaimer was buried under the notification prompt.** Presented in the
> same run loop, iOS put the system alert on top and the disclaimer was invisible
> behind it. The notification request is now sequenced to run after the disclaimer
> is acknowledged. A disclaimer nobody sees is worth nothing for 1.4.1.
>
> **3. The "clinical vocabulary" finding in report.md §A5 was overstated.** Checking
> the actual user-facing strings: the result screen says "X% of syllables stuttered"
> in plain English with confidence-based hedging, onboarding already carries an
> accuracy note ending "rather than a clinical diagnosis", and "clinical breakdown"
> appears only in **code comments**, never on screen. The copy was already
> reasonable; the genuine gap was the missing disclaimer, which is now closed. No
> rewording was needed and none was done.

### Not verified
- [ ] The legal link row renders correctly on both screens — built and compiling, but the simulator panel tooling crashed before it could be confirmed visually. Uses the same stack-view insertion already proven for the Apple button and the guest delete button, so the mechanism is sound; still worth an eyeball

### Yours to do
- [ ] **Fill in the real URLs in `LegalLinks.swift` and set `isConfigured = true`.** Until you do, tapping a legal link shows an honest "not published yet" message rather than opening a 404 — deliberately, so an unfilled placeholder is visible rather than silent
- [ ] Replace `support@spasht.app` with the real support address
- [ ] Mirror `PrivacyInfo.xcprivacy` in the App Store Connect App Privacy questionnaire — **including Health**, which is now declared (reasoning in the manifest's comment)

**Exit criteria:** No placeholder content, no debug surface, no vague purpose string, and the privacy manifest matches reality.

---

## Phase 5 — Quality and correctness

**Goal:** The things that would make a reviewer — or a real user — think the app is unfinished.
**Status:** Q1, Q2, Q3, A7, Q5 and Q7 done 18 Sep 2026. Debug and Release both build. **Q9 deferred.**

### Done in the repo
- [x] **Q1 — the login data-loss bug is fixed, and the fix is verified.** `completeSignIn` is now transactional: `LocalDataSnapshot` photocopies all three SQLite databases before the destructive reset and puts them back if any part of the sync throws, also reverting session mode and the onboarding flag
- [x] **Q2 — password reset now returns to the app.** `spasht://` scheme registered, `resetPasswordForEmail` carries a `redirectTo`, `SceneDelegate` routes recovery links, and `PasswordRecovery` exchanges the link for a session and prompts for a new password in-app
- [x] **Q3 — the email-confirmation dead end is gone.** Resend and "Go to Sign In" actions replace the bare "check your email" alert
- [x] **A7 — the 464 MB model no longer loads on the launch path.** `WhisperDetectionManager.prewarm()` is called from the home screen once the app is interactive, instead of from `didFinishLaunchingWithOptions`
- [x] **Q5 (targeted) — no user identifier is printed any more.** `deviceId`, `userId`, `guestId` and `newUserId` are all out of the log lines
- [x] **Q7 — deployment targets aligned** at 26.0 across project and target
- [x] **Build verified** — Debug and Release

> ### Q1 was verified, not just written
>
> A data-loss fix that is only reasoned about is not fixed. The login path needs
> account credentials to exercise, which this session did not have, so the
> snapshot mechanism itself was tested directly with a temporary launch-argument
> probe: seed the databases, capture, wipe, restore, hash the bytes at each step.
>
> ```
> BEFORE   ExerciseDatabase=b322dffdb713  Spasht=56c523673135
> WIPED    ExerciseDatabase=53a1ab770c7f  Spasht=cd3f0ba867c8
> RESTORED ExerciseDatabase=b322dffdb713  Spasht=56c523673135
> ```
>
> Byte-identical after restore, and demonstrably different while wiped — so the
> wipe is real and the restore is exact. (AwardsDB hashes the same throughout
> because it reseeds deterministically from JSON.) The probe was removed after
> the run; `AppDelegate` is back to its committed shape.
>
> Note the first attempt compared **file sizes** and showed no difference between
> BEFORE and WIPED — reset recreates and reseeds to the same page-aligned size.
> A size check would have "passed" without testing anything.

> ### Q7: lowering the deployment target is far cheaper than assumed
>
> report.md guessed that "likely nothing" required iOS 26. Measured instead, by
> building with `IPHONEOS_DEPLOYMENT_TARGET=18.0`: **64 errors across exactly 4
> files.**
>
> | File | Blocker |
> |------|---------|
> | `Model/Reading/AIParagraphGenerator.swift` | Foundation Models — `LanguageModelSession`, `SystemLanguageModel` |
> | `View/Conversation/VoiceViewController.swift` | `.glass()` |
> | `View/Exercises/ControlsTemplateViewController.swift` | `.glass()` |
> | `View/Exercises/ExerciseInstructionViewController.swift` | `.glass()` |
>
> So supporting iOS 18 means `if #available(iOS 26, *)` around the Liquid Glass
> styling, and an availability guard on the on-device paragraph generator — which
> already has a Groq fallback path in `generateLongForm`. That is roughly half a
> day, not a rewrite.
>
> **Not done here**, because it is a product decision with visual consequences and
> nobody asked for it. But the current setting excludes the large majority of
> installed iPhones, and now you know the actual price of changing that.

### Deferred
- [ ] **Q5 (full)** — the remaining ~300 `print()` calls still aren't `os.Logger`. The privacy half is done; the rest is churn with little return before submission
- [ ] **Q9 — accessibility.** Not started. Still worth a VoiceOver and largest-Dynamic-Type pass over the main flows before shipping; fixed frames in the storyboards suggest the score ring and reading view will clip. For an app built for people with a speech disability this deserves real time, not a rushed pass

### Yours to do
- [x] Add `spasht://password-reset` to **Supabase → Authentication → URL Configuration → Redirect URLs** — done 18 Sep 2026
- [ ] Test forgot-password end to end on a device once that is set
- [ ] Decide on the iOS 18 question above

**Exit criteria:** Q1 fixed and verified by forcing a sync failure mid-login. The rest triaged honestly — anything deferred is written down, not forgotten.

---

## Phase 6 — Verification

**Goal:** Prove it works on real hardware and capture the evidence Apple asked for.
**Blocked by:** Phases 2–4.
**Time:** 1 day.

- [ ] Full regression on a **physical device**: fresh install → guest → upgrade to account → onboarding → reading session → exercise → conversation → awards → sign out → sign back in
- [ ] Repeat for each auth path: email, Google, Apple
- [ ] Airplane-mode test on login and mid-session sync (this is what catches Q1 regressions)
- [ ] **Record the deletion flow on a physical device** — create/sign into the demo account → navigate to Delete Account → complete flow → confirmation. This recording is what Apple explicitly asked for
- [ ] Create the App Review demo account, pre-confirmed, with realistic data in it
- [ ] Re-shoot all App Store screenshots from a real build showing the Apple button — **not** `-MockHome`, which no longer exists after Phase 4
- [ ] Bump `CURRENT_PROJECT_VERSION` (still `1`)

**Exit criteria:** A build that survives the full matrix, plus the video and screenshots in hand.

---

## Phase 7 — Submit

**Blocked by:** Phase 6.
**Time:** half a day.

- [ ] Privacy policy URL set in App Store Connect
- [ ] App Privacy questionnaire matches `PrivacyInfo.xcprivacy` exactly, **Health included**
- [ ] Demo account credentials in App Review Information
- [ ] Deletion screen recording in the Notes field
- [ ] Description scrubbed of "therapy", "treatment", "diagnosis", "clinically proven"
- [ ] Age rating reviewed — user-generated audio/video and an LLM conversation partner both affect it
- [ ] Upload, then reply on **both** open review threads (draft text in report.md §7)

---

## Cut lines, if time runs short

Ship anyway without: Q5 (logging), Q7 (deployment target), Q9 (accessibility pass), D5 (model size).

Do **not** ship without: Phase 0, Phase 2, Phase 3, and from Phase 4 the `MockHomeScreen` deletion, the privacy policy links, and the purpose strings. Q1 is a data-loss bug reachable by any user on a bad connection — treat it as a blocker even though Apple will never see it.
