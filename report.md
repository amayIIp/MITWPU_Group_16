# Spasht — App Store Submission Report

**Prepared:** 18 September 2026
**Target:** `com.spasht.app1` · Spasht v1.0
**Scope:** The two App Review rejections (Guideline 4.8, Guideline 5.1.1(v)) plus everything else found in a full pass over the codebase that would either block a future review or make the app look unfinished.

---

## 1. Executive summary

Two issues are hard blockers from Apple. Reviewing the code turned up a further **seven issues that are likely or possible rejection triggers** on the next submission, and a set of quality problems worth clearing before you ship v1.0.

### Blockers — Apple has already rejected on these

| # | Guideline | Issue | Where it stands today |
|---|-----------|-------|-----------------------|
| **B1** | 4.8 Login Services | Google Sign-In is offered with no equivalent privacy-preserving option | No `AuthenticationServices` import anywhere; no Sign in with Apple capability in the project; no entitlements file exists |
| **B2** | 5.1.1(v) Data Collection | Account creation exists, account deletion does not | `grep` for `delete` across the app finds nothing; the Settings list is Profile / Set Goals / Summary / About Us / Log Out |

### Additional findings — fix before resubmitting

| # | Guideline | Issue | Severity |
|---|-----------|-------|----------|
| **A1** | 5.1.1(i) / ASC metadata | No privacy policy or terms link anywhere in the app | **Likely rejection** |
| **A2** | 5.1.1 | Purpose strings for mic/camera/speech are vague placeholders | **Likely rejection** |
| **A3** | 2.3.1 / 2.5.1 | `MockHomeScreen.swift` ships a fake home screen in the release binary, used to make App Store screenshots | **Likely rejection** |
| **A4** | 2.3.1 / 4.0 | Lorem ipsum is the design-time text on two production screens | **Possible rejection** |
| **A5** | 1.4.1 / 5.1.3 | Clinical framing ("percent syllables stuttered", "speech therapy coach") with no non-diagnostic disclaimer | **Possible rejection** |
| **A6** | 5.1.2 / ASC privacy | `PrivacyInfo.xcprivacy` declares no collected data types, while the app collects name, email, phone, and audio | **Possible rejection** |
| **A7** | 2.1 Performance | 464 MB Whisper model loaded during `didFinishLaunchingWithOptions` — launch-watchdog risk | **Possible rejection** |
| **S1** | — | Groq API key is compiled into the shipped binary and extractable from the IPA | **Security — urgent** |
| **S2** | — | `.gitignore` does not match where `AppSecrets.swift` actually lives | **Security — urgent** |
| **S3** | — | Supabase RLS on all 12 tables is unverified | **Security — verify** |
| **Q1–Q9** | — | Quality and correctness items, section 6 | Polish |

### Order of work

The executable plan lives in **[PHASES.md](PHASES.md)** — eight phases sequenced by dependency, with exit criteria and decision gates. This document is the analysis; that one is the checklist to work through.

In outline: contain the secrets (Phase 0) → portal, Supabase and privacy-policy groundwork (Phase 1) → Sign in with Apple (Phase 2) → account deletion and the Groq proxy (Phase 3) → compliance surface (Phase 4) → quality and the login data-loss bug (Phase 5) → device verification and the deletion recording (Phase 6) → submit (Phase 7). Roughly 8–11 working days for one developer.

---

## 2. What Apple actually asked for

Apple's two messages want different kinds of response, and it is worth being precise:

**On 4.8**, Apple offers you two routes: implement a qualifying login service, *or* reply explaining that you already have one. You do **not** have one. Your email/password system would exempt you from 4.8 entirely *if it were the only option* ("Your app exclusively uses your company's own account setup and sign-in systems"), but the moment Google Sign-In is on the screen the exemption is gone. So the answer is Sign in with Apple; there is no reply-and-explain route here.

**On 5.1.1(v)**, Apple has asked for a **screen recording captured on a physical device** showing: creating/signing into an account → navigating to the delete option → the complete flow through to confirmation. That recording goes in the App Review Information → Notes field. Plan to produce it; the feature alone will not close the ticket.

Both messages also note you must **update your App Store screenshots** once the sign-in screen changes. Since your current screenshots were made with `-MockHome` (see A3), they need redoing anyway.

---

## 3. B1 — Sign in with Apple (Guideline 4.8)

### 3.1 What has to be true when you're done

- The Sign in with Apple button appears on **both** `LoginViewController` and `SignUpViewController`, wherever the Google button appears.
- It is **at least as prominent** as the Google button — same width, same or higher in the stack, not smaller and not below the fold. Apple checks this. Using `ASAuthorizationAppleIDButton` gives you the correct size, corner radius, label, and localization for free; don't hand-roll it.
- It creates a real primary account, identical in capability to a Google or email account — same onboarding, same sync, same data.
- Account deletion (B2) revokes the Apple token. These two work items are coupled; do B1 first.

### 3.2 Apple Developer portal and Xcode setup

1. **Certificates, Identifiers & Profiles → Identifiers → `com.spasht.app1`** → enable the **Sign in with Apple** capability → Save. (Team `C2N3Q4846H`.)
2. **Keys → +** → name it e.g. "Spasht SIWA" → tick **Sign in with Apple** → Configure → pick the primary App ID `com.spasht.app1` → Continue → Register. **Download the `.p8` once** — Apple will not let you download it again. Note the **Key ID** and your **Team ID**. You need these in §4 for token revocation.
3. **Xcode → target "Stuttering App" → Signing & Capabilities → + Capability → Sign in with Apple.** This creates `Stuttering App/Stuttering App.entitlements` containing `com.apple.developer.applesignin = [Default]` and sets `CODE_SIGN_ENTITLEMENTS` in the project. Neither exists today — confirm both appear.
4. **Supabase dashboard → Authentication → Providers → Apple** → enable → put `com.spasht.app1` in the **Client IDs** field. For a native-only app you do **not** need a Services ID, the OAuth secret, or the 6-month secret rotation; the Client IDs entry is enough for `signInWithIdToken`.

### 3.3 New file: `Stuttering App/Model/Networking/AppleSignInManager.swift`

This mirrors the existing Google flow — same nonce helper, same `signInWithIdToken` shape — so the two paths stay readable side by side.

```swift
//
//  AppleSignInManager.swift
//  Spasht
//
//  Native Sign in with Apple, exchanged for a Supabase session.
//  Mirrors the Google flow in LoginViewController / SignUpViewController.
//

import AuthenticationServices
import Supabase
import UIKit

/// What a completed Apple authorization gives us.
struct AppleSignInResult {
    let supabaseUserId: String

    /// Apple returns the name only on the *first* authorization for this
    /// Apple ID + app pair. It is nil on every later sign-in, so it has to be
    /// persisted the moment we see it.
    let fullName: String?

    /// Exchanged server-side for a refresh token, which account deletion later
    /// revokes. Apple requires revocation as part of 5.1.1(v).
    let authorizationCode: String?
}

@MainActor
final class AppleSignInManager: NSObject {

    static let shared = AppleSignInManager()
    private override init() { super.init() }

    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private weak var anchorWindow: UIWindow?

    /// Runs the native Apple flow and trades the identity token for a Supabase
    /// session. Throws on cancellation so callers can distinguish it.
    func signIn(presentingFrom viewController: UIViewController) async throws -> AppleSignInResult {
        let rawNonce = AuthHelpers.randomNonceString()
        anchorWindow = viewController.view.window

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        // Apple embeds SHA-256(nonce) as the `nonce` claim in the identity
        // token; Supabase recomputes that digest from the raw value we pass to
        // signInWithIdToken. Same contract as the Google path.
        request.nonce = AuthHelpers.sha256(rawNonce)

        let credential: ASAuthorizationAppleIDCredential = try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            controller.performRequests()
        }

        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AppleSignInError.missingIdentityToken
        }

        _ = try await SupabaseManager.shared.client.auth.signInWithIdToken(
            credentials: .init(provider: .apple, idToken: idToken, nonce: rawNonce)
        )

        guard let userId = SupabaseManager.shared.currentUser?.id.uuidString else {
            throw AppleSignInError.noUserAfterSignIn
        }

        let name = [credential.fullName?.givenName, credential.fullName?.familyName]
            .compactMap { $0 }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)

        return AppleSignInResult(
            supabaseUserId: userId,
            fullName: name.isEmpty ? nil : name,
            authorizationCode: credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }

    enum AppleSignInError: LocalizedError {
        case missingIdentityToken
        case noUserAfterSignIn
        case cancelled

        var errorDescription: String? {
            switch self {
            case .missingIdentityToken: return "Apple didn't return an identity token. Please try again."
            case .noUserAfterSignIn:    return "Signed in with Apple, but no account was created. Please try again."
            case .cancelled:            return "Sign in with Apple was cancelled."
            }
        }
    }
}

// MARK: - ASAuthorizationControllerDelegate

extension AppleSignInManager: ASAuthorizationControllerDelegate {

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            continuation?.resume(throwing: AppleSignInError.missingIdentityToken)
            continuation = nil
            return
        }
        continuation?.resume(returning: credential)
        continuation = nil
    }

    func authorizationController(controller: ASAuthorizationController,
                                 didCompleteWithError error: Error) {
        let resolved: Error = (error as? ASAuthorizationError)?.code == .canceled
            ? AppleSignInError.cancelled
            : error
        continuation?.resume(throwing: resolved)
        continuation = nil
    }
}

// MARK: - ASAuthorizationControllerPresentationContextProviding

extension AppleSignInManager: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        anchorWindow ?? UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? UIWindow()
    }
}
```

> **Note on cancellation:** the user tapping Cancel in the Apple sheet must not show a "Sign in failed" alert. That is why `.cancelled` is a distinct case — handle it by just dismissing the loading overlay.

### 3.4 Wiring it into `LoginViewController`

The post-auth work in `loginButtonTapped` and `googleSignInTapped` is duplicated line for line today. Adding a third copy for Apple would make three. **Extract it once** and call it from all three:

```swift
// LoginViewController.swift

/// Everything that has to happen after any successful authentication.
/// Previously duplicated between the email and Google paths; Apple makes it
/// three, so it lives in one place now.
private func completeSignIn(userId: String) async throws {
    if SessionManager.shared.isGuestMode {
        LogManager.shared.migrateGuestData(to: userId)
        try await SupabaseSyncManager.shared.pushAllLocalDataToCloud()
    }

    SessionManager.shared.startAccountSession(userId: userId)

    LogManager.shared.resetDatabaseForNewUser()
    DatabaseManager.shared.resetDatabaseForNewUser()
    AwardsManager.shared.resetDatabaseForNewUser()
    AppState.resetModuleOnboarding()
    LogManager.shared.initializeUserIfNeeded()

    try await SupabaseSyncManager.shared.syncAllDataFromCloud()
    await SupabaseSyncManager.shared.reapplyDailyTaskCompletions()

    await MainActor.run {
        LogicMaker().checkForNewDay(isFromLogin: true)
    }
}
```

See **Q1** in §6 — there is a real data-loss bug inside this block that should be fixed while you are in there.

Then the Apple handler:

```swift
@IBOutlet weak var appleSignInContainer: UIStackView!   // or a plain UIView
private let appleButton = ASAuthorizationAppleIDButton(type: .continue, style: .black)

// in viewDidLoad(), after setupUI()
appleButton.cornerRadius = 12          // match the Google button
appleButton.addTarget(self, action: #selector(appleSignInTapped), for: .touchUpInside)
appleSignInContainer.addArrangedSubview(appleButton)
appleButton.heightAnchor.constraint(equalToConstant: 50).isActive = true

@objc private func appleSignInTapped() {
    showLoading(message: "Connecting with Apple")
    Task {
        do {
            let result = try await AppleSignInManager.shared.signIn(presentingFrom: self)

            try await completeSignIn(userId: result.supabaseUserId)

            // Apple hands the name over exactly once. Persist it now or lose it.
            if let name = result.fullName {
                var profile = LogManager.shared.getProfile(userId: result.supabaseUserId)
                    ?? UserProfile(id: result.supabaseUserId, isOnboardingCompleted: false)
                if profile.firstName?.isEmpty ?? true {
                    profile.firstName = name
                    LogManager.shared.saveProfile(profile)
                }
                try? await SupabaseManager.shared.client.auth.update(
                    user: UserAttributes(data: ["first_name": .string(name)])
                )
            }

            // Hand the authorization code to the backend so deletion can
            // revoke the token later (see §4.4).
            if let code = result.authorizationCode {
                await AccountDeletionService.shared.registerAppleAuthorizationCode(code)
            }

            await MainActor.run {
                self.hideLoading()
                self.performLoginTransition()
            }
        } catch AppleSignInManager.AppleSignInError.cancelled {
            await MainActor.run { self.hideLoading() }   // silent — user chose to back out
        } catch {
            await MainActor.run {
                self.hideLoading()
                self.showAlert(title: "Sign in with Apple Failed", message: error.localizedDescription)
            }
        }
    }
}
```

Repeat the same in `SignUpViewController` (its `handleNavigationLogic()` replaces `performLoginTransition()`).

### 3.5 Storyboard changes

In `Onboarding.storyboard`, on both the `LoginViewController` and `SignUpViewController` scenes:

- Add a `UIStackView` **above** the existing Google button, pinned to the same leading/trailing constraints, and connect it as `appleSignInContainer`.
- Apple above Google reads as "equivalent or better prominence" and is the safest arrangement.
- Do **not** make the Apple button shorter, narrower, or visually quieter than Google's — that is the single most common cause of a repeat 4.8 rejection.

### 3.6 Two things that will bite you

**Private Relay email.** Users who pick "Hide My Email" get an `@privaterelay.appleid.com` address. Supabase sends mail (password reset, confirmation) to that address, and Apple silently drops mail from unregistered senders. Register your sending domain under **Certificates, Identifiers & Profiles → Services → Sign in with Apple for Email Communication**. If you don't, Apple-relay users who later try "Forgot Password" get nothing.

**Identity collision.** If someone signed up with Google under `x@gmail.com` and then uses Apple with the same address, Supabase either links the identities or creates a second account depending on **Authentication → Settings → "Allow linking identities with the same email"**. Decide this deliberately and test it — two accounts holding half a user's practice history each is a bad first impression.

---

## 4. B2 — Account deletion (Guideline 5.1.1(v))

### 4.1 What Apple requires

Straight from Apple's *Offering account deletion in your app* page:

- Delete the **account record and all associated personal data**, including user-generated content — not a deactivation, not a disable.
- Make it **easy to find** — account settings is the expected place.
- Confirmation steps to prevent accidents are fine; forcing a phone call or email is not (that's reserved for highly-regulated industries).
- Apps using **Sign in with Apple must call the Apple REST API to revoke user tokens**.
- **Automatically generated accounts count.** Your guest mode creates a `deviceId`-keyed local account; users need a way to wipe it too.
- Must be available to **all users in all regions**, not just GDPR/CCPA jurisdictions.

### 4.2 What has to be deleted

| Where | What | How it's keyed |
|-------|------|----------------|
| Supabase `auth.users` | The account itself | `user.id` |
| Supabase tables (12) | `profiles`, `reading_sessions`, `session_letter_stats`, `letter_stats`, `troubled_words`, `daily_tasks`, `exercise_logs`, `conversation_sessions`, `journeys`, `streaks`, `user_awards`, `user_goals` | `user_id` |
| Local SQLite × 3 | `LogManager`, `DatabaseManager`, `AwardsManager` databases in Documents | already have `resetDatabaseForNewUser()` |
| Documents directory | Video diary `.mov` files, Story Cubes `.m4a` files | written by `FunExerciseManager`, `VideoDiaryViewController`, `StoryCubesViewController` |
| `UserDefaults` | Session keys, onboarding flags, module-onboarding flags, `deviceId` | `SessionManager.endSession()` covers most, **not** `deviceId` |
| Keychain | Supabase JWT | `auth.signOut()` |
| Apple | The SIWA token grant | REST revoke — §4.4 |

Note that `SessionManager.endSession()` deliberately **preserves** `deviceId`. For a logout that is right. For a deletion it is wrong — the whole point is that nothing identifying survives. Clear it.

### 4.3 Step 1 — make the database clean itself up

Run this in the Supabase SQL editor. Cascade deletes turn "delete 12 tables in the right order without missing one" into one statement, and they keep working when you add table 13.

```sql
-- Repeat for each of the 12 tables. Adjust the column name if a table
-- keys its owner differently.
alter table public.reading_sessions
  drop constraint if exists reading_sessions_user_id_fkey,
  add constraint reading_sessions_user_id_fkey
    foreign key (user_id) references auth.users(id) on delete cascade;
```

Then `auth.admin.deleteUser(id)` removes everything in one call. Verify with a throwaway account before trusting it — belt and braces, the Edge Function below also deletes explicitly.

### 4.4 Step 2 — the Edge Function

A client can never delete an `auth.users` row; that needs the service role key, which must never ship in the app. So deletion goes through an Edge Function.

**`supabase/functions/delete-account/index.ts`**

```ts
import { createClient } from "jsr:@supabase/supabase-js@2";
import { create, getNumericDate } from "https://deno.land/x/djwt@v3.0.2/mod.ts";

const SUPABASE_URL      = Deno.env.get("SUPABASE_URL")!;
const SUPABASE_ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY")!;
const SERVICE_ROLE_KEY  = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// From the Apple Developer portal — see §3.2 step 2.
const APPLE_TEAM_ID   = Deno.env.get("APPLE_TEAM_ID")!;
const APPLE_KEY_ID    = Deno.env.get("APPLE_KEY_ID")!;
const APPLE_CLIENT_ID = "com.spasht.app1";
const APPLE_P8        = Deno.env.get("APPLE_PRIVATE_KEY")!;   // full .p8 contents

const TABLES = [
  "reading_sessions", "session_letter_stats", "letter_stats", "troubled_words",
  "daily_tasks", "exercise_logs", "conversation_sessions", "journeys",
  "streaks", "user_awards", "user_goals", "profiles",
];

/// Apple's client_secret is an ES256 JWT signed with the .p8 key.
async function appleClientSecret(): Promise<string> {
  const pem = APPLE_P8
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s/g, "");
  const key = await crypto.subtle.importKey(
    "pkcs8",
    Uint8Array.from(atob(pem), (c) => c.charCodeAt(0)),
    { name: "ECDSA", namedCurve: "P-256" },
    false,
    ["sign"],
  );
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

/// Apple requires token revocation when a SIWA account is deleted.
async function revokeAppleToken(refreshToken: string) {
  const secret = await appleClientSecret();
  const res = await fetch("https://appleid.apple.com/auth/revoke", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({
      client_id: APPLE_CLIENT_ID,
      client_secret: secret,
      token: refreshToken,
      token_type_hint: "refresh_token",
    }),
  });
  if (!res.ok) console.error("Apple revoke failed:", res.status, await res.text());
}

Deno.serve(async (req) => {
  if (req.method !== "POST") return new Response("Method not allowed", { status: 405 });

  const authHeader = req.headers.get("Authorization");
  if (!authHeader) return new Response("Unauthorized", { status: 401 });

  // Identify the caller from their own JWT — never trust a user id in the body.
  const asUser = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });
  const { data: { user }, error } = await asUser.auth.getUser();
  if (error || !user) return new Response("Unauthorized", { status: 401 });

  const admin = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

  // 1. Revoke the Apple grant, if this account has one.
  const { data: appleRow } = await admin
    .from("apple_tokens").select("refresh_token").eq("user_id", user.id).maybeSingle();
  if (appleRow?.refresh_token) await revokeAppleToken(appleRow.refresh_token);
  await admin.from("apple_tokens").delete().eq("user_id", user.id);

  // 2. Delete application rows explicitly (cascade should already cover this;
  //    doing both means a missing FK doesn't silently orphan data).
  for (const table of TABLES) {
    const { error: e } = await admin.from(table).delete().eq("user_id", user.id);
    if (e) console.error(`delete ${table}:`, e.message);
  }

  // 3. Delete the auth record itself.
  const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
  if (delErr) {
    return new Response(JSON.stringify({ error: delErr.message }), {
      status: 500, headers: { "Content-Type": "application/json" },
    });
  }

  return new Response(JSON.stringify({ deleted: true }), {
    status: 200, headers: { "Content-Type": "application/json" },
  });
});
```

Deploy with `supabase functions deploy delete-account`, and set the secrets with `supabase secrets set APPLE_TEAM_ID=… APPLE_KEY_ID=… APPLE_PRIVATE_KEY="$(cat AuthKey_XXXX.p8)"`.

**Companion function `apple-register-code`** (called at sign-in, §3.4): POSTs the `authorizationCode` to `https://appleid.apple.com/auth/token` with `grant_type=authorization_code` and the same `client_secret`, then stores the returned `refresh_token` in `apple_tokens` (service-role-only table, RLS on, no client policies). Apple's authorization code is single-use and expires in five minutes, so this must happen immediately after sign-in, not lazily at deletion time.

> **Phasing note:** if the revocation plumbing can't land in time, ship deletion *without* it rather than shipping no deletion at all — deletion is what Apple rejected on. But treat revocation as required, not optional: it is written into Apple's own account-deletion requirements and reviewers do cite it.

### 4.5 Step 3 — the client service

**`Stuttering App/Model/Networking/AccountDeletionService.swift`**

```swift
//
//  AccountDeletionService.swift
//  Spasht
//
//  Guideline 5.1.1(v): account deletion must remove the account record and all
//  associated data — cloud, local database, and on-disk media.
//

import Foundation
import Supabase

@MainActor
final class AccountDeletionService {

    static let shared = AccountDeletionService()
    private init() {}

    enum DeletionError: LocalizedError {
        case notSignedIn
        case serverRefused(String)

        var errorDescription: String? {
            switch self {
            case .notSignedIn:
                return "You're not signed in."
            case .serverRefused(let reason):
                return "We couldn't delete your account: \(reason)"
            }
        }
    }

    /// Deletes an account: Supabase auth record, all cloud rows, all local data.
    func deleteAccount() async throws {
        guard SessionManager.shared.isAccountMode else { throw DeletionError.notSignedIn }

        do {
            _ = try await SupabaseManager.shared.client.functions
                .invoke("delete-account", options: .init(method: .post))
        } catch {
            throw DeletionError.serverRefused(error.localizedDescription)
        }

        await wipeEverythingLocal()
    }

    /// Guest mode has no cloud footprint, but Apple's account-deletion FAQ
    /// covers automatically generated accounts too — so guests get the same
    /// destination, just without the network call.
    func deleteGuestData() async {
        await wipeEverythingLocal()
    }

    /// Stores the Apple authorization code server-side so deletion can revoke
    /// the grant. Best-effort: a failure here must not block sign-in.
    func registerAppleAuthorizationCode(_ code: String) async {
        do {
            _ = try await SupabaseManager.shared.client.functions.invoke(
                "apple-register-code",
                options: .init(method: .post, body: ["authorization_code": code])
            )
        } catch {
            print("Apple code registration failed: \(error)")
        }
    }

    // MARK: - Local teardown

    private func wipeEverythingLocal() async {
        deleteUserMediaFiles()

        LogManager.shared.resetDatabaseForNewUser()
        DatabaseManager.shared.resetDatabaseForNewUser()
        AwardsManager.shared.resetDatabaseForNewUser()
        AppState.resetModuleOnboarding()
        LogManager.shared.cachedHomeInsight = nil

        await SessionManager.shared.endSession()

        // endSession() preserves deviceId, which is correct for a sign-out and
        // wrong for a deletion — nothing identifying should survive this.
        UserDefaults.standard.removeObject(forKey: "session.deviceId")

        NotificationManager.shared.cancelAllNotifications()
    }

    /// Video diary recordings and Story Cubes audio live loose in Documents.
    private func deleteUserMediaFiles() {
        let fm = FileManager.default
        guard let documents = fm.urls(for: .documentDirectory, in: .userDomainMask).first,
              let contents = try? fm.contentsOfDirectory(at: documents,
                                                         includingPropertiesForKeys: nil) else { return }
        for url in contents where ["m4a", "mov", "mp4", "wav"].contains(url.pathExtension.lowercased()) {
            try? fm.removeItem(at: url)
        }
    }
}
```

> `NotificationManager.cancelAllNotifications()` may not exist yet — check `Model/HomePage/NotificationManager.swift` and add it if not. Leaving scheduled local notifications firing after a deletion is exactly the kind of loose end a reviewer notices.

### 4.6 Step 4 — the UI

Add a **Delete Account** row to `ProfileTableViewController`'s settings list, below Log Out, in its own section with a red destructive label. Then:

```swift
// ProfileTableViewController.swift

@IBAction func deleteAccountTapped(_ sender: Any) {
    let isGuest = SessionManager.shared.isGuestMode

    let alert = UIAlertController(
        title: isGuest ? "Delete All Data?" : "Delete Account?",
        message: isGuest
            ? "This permanently deletes your practice history, recordings, and progress from this device. This cannot be undone."
            : "This permanently deletes your account and everything in it — your practice history, recordings, streaks, and awards, on this device and in the cloud. This cannot be undone.",
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { _ in
        self.confirmDeletion(isGuest: isGuest)
    })
    present(alert, animated: true)
}

/// Second, deliberately slower confirmation. Apple allows confirmation steps
/// to prevent accidents; what it forbids is making deletion *hard*, so this
/// stops at two taps plus a typed word — no email, no phone call.
private func confirmDeletion(isGuest: Bool) {
    let confirm = UIAlertController(
        title: "Are you sure?",
        message: "Type DELETE to confirm.",
        preferredStyle: .alert
    )
    confirm.addTextField { $0.autocapitalizationType = .allCharacters }
    confirm.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    confirm.addAction(UIAlertAction(title: "Delete Permanently", style: .destructive) { [weak confirm] _ in
        guard confirm?.textFields?.first?.text?.uppercased() == "DELETE" else {
            self.showAlert(title: "Not Deleted", message: "Type DELETE to confirm.")
            return
        }
        self.performDeletion(isGuest: isGuest)
    })
    present(confirm, animated: true)
}

private func performDeletion(isGuest: Bool) {
    let overlay = WaveLoadingOverlay.showOnWindow(message: "Deleting your account")
    Task {
        do {
            if isGuest {
                await AccountDeletionService.shared.deleteGuestData()
            } else {
                try await AccountDeletionService.shared.deleteAccount()
            }
            overlay.dismiss()
            showDeletionConfirmedThenReturnToLanding()
        } catch {
            overlay.dismiss()
            showAlert(title: "Couldn't Delete Account", message: error.localizedDescription)
        }
    }
}

/// Apple asks for an explicit confirmation that deletion completed.
private func showDeletionConfirmedThenReturnToLanding() {
    let done = UIAlertController(
        title: "Account Deleted",
        message: "Your account and all of its data have been permanently deleted.",
        preferredStyle: .alert
    )
    done.addAction(UIAlertAction(title: "OK", style: .default) { _ in
        self.returnToLanding()
    })
    present(done, animated: true)
}

private func returnToLanding() {
    let storyboard = UIStoryboard(name: "Onboarding", bundle: nil)
    guard let landingNav = storyboard.instantiateViewController(withIdentifier: "LandingNav") as? UINavigationController,
          let sceneDelegate = view.window?.windowScene?.delegate as? SceneDelegate,
          let window = sceneDelegate.window else { return }
    UIView.transition(with: window, duration: 0.5, options: .transitionCrossDissolve) {
        window.rootViewController = landingNav
    }
}
```

Design notes that matter to the reviewer:

- The row must be reachable from Settings **without signing out first** — no more than two or three taps from the home screen.
- The confirmation dialog must state clearly that deletion is **permanent** and covers **all** data. Vague wording reads as "deactivate" and gets re-rejected.
- The explicit "Account Deleted" confirmation is Apple's requirement, not decoration.

### 4.7 Testing before you record the video

1. Create a fresh account → complete onboarding → do one reading session, one story cube recording, one video diary entry → earn an award.
2. Confirm rows appear in all relevant Supabase tables.
3. Delete the account from Settings.
4. Confirm in Supabase: **zero** rows for that `user_id` in all 12 tables, and the `auth.users` row is gone.
5. Try signing back in with the same credentials — it must fail.
6. Repeat with a Sign in with Apple account and check **Settings → [your name] → Sign in with Apple** on the device: Spasht should no longer be listed. This is the visible proof that revocation worked.
7. Repeat in guest mode.
8. Record run 6 on a **physical device** for App Review Notes.

---

## 5. Additional issues found in this session

### S1 — Groq API key ships inside the binary *(urgent)*

`Stuttering App/AppSecrets.swift` contains a live Groq key that `GroqService` compiles into the app. String constants in a Swift binary are trivially recoverable from an IPA — `strings` on the decrypted binary is enough. Anyone who downloads Spasht can extract that key and bill inference against your account until it's exhausted.

There is also a **Gemini key that nothing uses** — `geminiAPIKey` has no references anywhere in the app.

**Fix, in order:**

1. **Rotate both keys now.** Both have been sitting in a working-tree file and must be considered compromised. The commented-out second Groq key suggests one has already been rotated once.
2. **Delete `geminiAPIKey`** — it's dead weight and dead risk.
3. **Move Groq behind an Edge Function.** You already need Edge Functions for §4, so this is marginal work: a `groq-chat` function holds the key as a secret, checks the caller's JWT, and forwards the request. The app then sends its Supabase session token instead of a provider key. This also gives you rate limiting per user, which you currently have no way to enforce.
4. The Supabase **publishable** key is fine to ship — that one is designed to be public, *provided* RLS is on (see S3).

### S2 — `.gitignore` doesn't cover where `AppSecrets.swift` actually lives *(urgent)*

`.gitignore` ignores:

```
Stuttering App/Networking/AppSecrets.swift
Stuttering App/Model/Networking/AppSecrets.swift
```

The file is actually at **`Stuttering App/AppSecrets.swift`**. `git status` confirms it as `??` — untracked *and unignored*. A single `git add .` commits your API keys to a repo with an open pull-request history. Fix:

```bash
printf '\n# API keys\nStuttering App/AppSecrets.swift\n' >> .gitignore
```

Add an `AppSecrets.example.swift` with empty values so a fresh clone still builds, and mention it in the README next to the model-download step.

### S3 — Verify Supabase RLS on every table *(verify)*

The app ships a publishable Supabase key, which is correct — but only if Row Level Security is enabled with per-user policies on all 12 tables. If RLS is off on even one, that key lets anyone read every user's speech-practice history. For an app handling speech-disability data, that's both a privacy incident and a 5.1.1/5.1.2 problem.

Check in the dashboard, or:

```sql
select tablename, rowsecurity
from pg_tables
where schemaname = 'public';
```

Every row must be `true`, and each table needs a policy of the shape `auth.uid() = user_id`.

### A1 — No privacy policy or terms anywhere in the app *(likely rejection)*

Searching every Swift file and storyboard for a URL turns up nothing but Supabase and Google endpoints. There is no privacy policy link, no terms link, and no support contact in the app.

App Store Connect requires a privacy policy URL as metadata, and Guideline 5.1.1(i) expects users to be able to reach it from inside an app that collects personal data. Add three rows to the Settings screen below About Us:

- **Privacy Policy** → `SFSafariViewController`
- **Terms of Use** → `SFSafariViewController`
- **Contact Support** → `mailto:` or a web form

The privacy policy must specifically cover: what Supabase stores, that speech transcripts and session metrics go to **Groq** (a third-party LLM provider) for coaching text, that audio is transcribed **on-device** by WhisperKit and not uploaded, what Google Sign-In receives, and how to delete an account.

### A2 — Purpose strings are placeholders *(likely rejection)*

Today, in `project.pbxproj`:

```
INFOPLIST_KEY_NSCameraUsageDescription = "Allow camera usage for camera input "
INFOPLIST_KEY_NSMicrophoneUsageDescription = "Allow microphone usage for audio input "
INFOPLIST_KEY_NSSpeechRecognitionUsageDescription = "Allow speech recognition for speech test "
```

These say nothing about *why*, and two carry a trailing space. Apple rejects vague purpose strings under 5.1.1 routinely. Replace with:

```
NSMicrophoneUsageDescription      = "Spasht records your voice while you read and practise so it can measure your fluency and show your progress."
NSSpeechRecognitionUsageDescription = "Spasht transcribes your speech on this device to follow along as you read and to identify where you stumbled."
NSCameraUsageDescription          = "Spasht uses the camera to record your video diary entries, which are saved only on this device."
```

Add `NSPhotoLibraryAddUsageDescription` only if you later let users export diary videos — right now they stay in the app's Documents directory, so it isn't needed.

### A3 — `MockHomeScreen.swift` ships in the release build *(likely rejection)*

`Stuttering App/View/HomePage/MockHomeScreen.swift` is a launch-argument-gated fake home screen. Its own header says:

> TEMPORARY — App Store screenshot helper. … Delete this file once the screenshots are captured.

Two separate problems:

1. **Screenshots built from it misrepresent the app.** Guideline 2.3.3 requires screenshots to show the app in actual use. Fabricated streaks and progress in store screenshots is exactly what that rule is about.
2. **It's undisclosed conditional functionality in the shipped binary** — `AppDelegate.didFinishLaunchingWithOptions` calls `MockHome.prepareLaunchStateIfNeeded()` unconditionally, and a launch argument flips the app into a different state. That is a 2.5.1 / 2.3.1 hidden-features pattern.

**Delete the file, delete the `AppDelegate` call, and re-shoot your screenshots from a real session.** If you need presentable data for screenshots, seed a real account by using the app for a week.

### A4 — Lorem ipsum on two production screens *(possible rejection)*

- `View/Reading/Reading.storyboard:25` — the reading passage text view
- `View/Conversation/Conversation.storyboard:26` — the conversation transcript text view

Both are replaced at runtime, but there is a window before the paragraph generator or the first conversation turn returns where a reviewer on a slow connection sees Latin filler. Clear the design-time text in Interface Builder and rely on an intentional empty state ("Preparing your passage…").

### A5 — Clinical framing with no disclaimer *(possible rejection)*

> **Correction, 18 Sep 2026 (Phase 4).** The vocabulary half of this finding was
> overstated. Checking the user-facing strings rather than the code: the result
> screen says "X% of syllables stuttered" in plain English with confidence-based
> hedging, onboarding already carries an accuracy note ending "rather than a
> clinical diagnosis", and "clinical breakdown" appears only in code comments,
> never on screen. Point 2 below therefore needed no action and none was taken.
> Point 1, the missing disclaimer, was real and is now implemented.

Spasht computes and displays **percent syllables stuttered**, described in the code as "the clinical measure", alongside a "clinical breakdown", and its LLM prompts cast it as a "supportive speech therapy coach". Guideline 1.4.1 holds apps that could be construed as providing medical diagnosis to a higher standard of accuracy and provenance.

The `VoiceViewModel` prompt already refuses medical advice, which is good and worth keeping. What's missing is the same honesty in the UI. Two changes:

1. **Add a visible disclaimer** — on first launch and on the Settings/About screen: *"Spasht is a practice tool, not a medical device. It does not diagnose or treat stuttering. For assessment or therapy, see a qualified speech-language pathologist."*
2. **Soften the clinical vocabulary in user-facing copy.** Per the read-aloud audit already on record, pooled detection recall is around 54%, and the acoustic thresholds in `SpeechEnvelope.Tuning` have never been calibrated against a real speaker. Presenting a number labelled with a clinical term at that accuracy is a claim the implementation doesn't support. "Fluency score" and "session breakdown" carry the same information without the clinical assertion; keep %SS in the diagnostics view where it belongs.

This also protects the App Store description — avoid "therapy", "treatment", "assessment", and "clinically proven" in your marketing text unless you can substantiate them.

### A6 — Privacy manifest declares no collected data *(possible rejection)*

`Stuttering App/PrivacyInfo.xcprivacy` is correctly picked up (the target uses a file-system-synchronized group, so it is bundled) and correctly declares `UserDefaults` and `FileTimestamp` API usage. But `NSPrivacyCollectedDataTypes` is **absent entirely**, while the app collects name, email address, phone number, and audio/video recordings, and syncs them to a server.

Add the collected-data section, and mirror it exactly in App Store Connect's App Privacy questionnaire:

```xml
<key>NSPrivacyCollectedDataTypes</key>
<array>
    <dict>
        <key>NSPrivacyCollectedDataType</key>
        <string>NSPrivacyCollectedDataTypeEmailAddress</string>
        <key>NSPrivacyCollectedDataTypeLinked</key><true/>
        <key>NSPrivacyCollectedDataTypeTracking</key><false/>
        <key>NSPrivacyCollectedDataTypePurposes</key>
        <array><string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string></array>
    </dict>
    <!-- repeat for: Name, PhoneNumber, AudioData, OtherUserContent,
         ProductInteraction, UserID -->
</array>
```

Because the app records speech from people who stutter, consider whether **Health & Fitness → Health** applies in the ASC questionnaire. Declaring it is safer than not; an under-declared privacy label is a common cause of a post-approval removal.

### A7 — Launch performance with a 464 MB model *(possible rejection)*

`AppDelegate.didFinishLaunchingWithOptions` fires three things before returning: `AwardsManager` database open + seed, `BackgroundParagraphManager.startInitialBatch()`, and `_ = WhisperDetectionManager.shared`, which starts loading a **464 MB** WhisperKit model.

iOS kills apps that don't finish launching within roughly 20 seconds (`0x8badf00d`), and App Review tests on devices under load. Worth checking and likely worth changing:

- Confirm `WhisperDetectionManager.shared` does its loading genuinely off the main thread and that nothing later blocks on it during launch.
- Defer the model load until the user first opens a reading session, with a visible "Preparing…" state.
- Consider shipping `openai_whisper-tiny.en` (the `.gitignore` suggests it was once in play) or using WhisperKit's on-demand model download. 464 MB also means cellular-download warnings, slower review turnaround, and a much worse first-run experience.
- Also note that per the read-aloud audit, Apple's `SFSpeechRecognizer` is now the primary transcript source with Whisper as an empty-only fallback. If that is still true, a 464 MB bundled model buys very little — worth a hard look at whether it needs to ship at all.

---

## 6. Quality and correctness items

**Q1 — Login wipes local data before the cloud sync that replaces it.** In `LoginViewController.loginButtonTapped`, the sequence is: reset all three SQLite databases → set `AppState.isOnboardingCompleted = false` → `try await syncAllDataFromCloud()`. If that sync throws — patchy hotel Wi-Fi, a Supabase blip — control jumps to the catch block, which shows "Login Failed" and stops. The user is now signed in with **three wiped databases and onboarding marked incomplete**, and the message blames their password. Restructure: fetch the cloud snapshot first, and only reset and repopulate once it has arrived successfully. `SignUpViewController`'s Google path has the same shape.

**Q2 — Password reset has no way back into the app.** `resetPasswordForEmail` sends a link, but there is no URL scheme or universal link registered for the Supabase recovery redirect and nothing handles it in `SceneDelegate`. The user taps the link in Mail and lands on a web page, never back in Spasht. Reviewers do test forgot-password. Register a redirect URL and handle the recovery deep link, or at minimum make sure the hosted page works and says what to do next.

**Q3 — Sign-up leaves the user stranded on email confirmation.** If Supabase email confirmation is on, `signUpButtonTapped` shows "check your email" and returns to the same form. No resend option, no "I've confirmed, take me in" path. Add a resend action, and supply App Review with a **pre-confirmed demo account** either way (this is required in App Review Information regardless).

**Q4 — `SessionDiagnosticsViewController` is a hidden debug surface in production.** Reached by long-pressing the score ring, deliberately undiscoverable, dumps internal pipeline state. Useful during development; it should not ship. Wrap the long-press gesture in `#if DEBUG`.

**Q5 — 306 `print()` calls, several logging user IDs.** `SessionManager` prints `deviceId` and Supabase user IDs to the device console on every launch. Release builds keep these. Move to `os.Logger` with `privacy: .private` on identifiers, or strip them behind `#if DEBUG`.

**Q6 — Export compliance isn't declared.** `ITSAppUsesNonExemptEncryption` is absent, so every TestFlight and App Store upload stops to ask the encryption question, delaying builds. The app uses only HTTPS and `CryptoKit` SHA-256 for OAuth nonces, both exempt. Add `INFOPLIST_KEY_ITSAppUsesNonExemptEncryption = NO` to both configurations.

**Q7 — Deployment target is iOS 26.0 and inconsistent between configurations.** Debug is `26.0`, another configuration reads `26.1`. iOS 26 launched a year ago; targeting it excludes the large majority of installed iPhones. It won't cause a rejection — reviewers run current OS versions — but it caps your addressable market severely. Check what actually requires iOS 26 (likely nothing but recent Foundation conveniences) and consider iOS 17 or 18. At minimum, make the two configurations agree.

**Q8 — Info.plist has an empty key.** The file opens with `<key></key><string></string>`, and `INFOPLIST_KEY_UIStatusBarStyle` is set to an empty string. Harmless in practice, but they're the kind of thing that generates confusing validation warnings at upload time. Remove both.

**Q9 — No accessibility pass has been done.** `UIUserInterfaceStyle = Light` forces light mode, which is permitted. But there's no evidence of a VoiceOver or Dynamic Type audit anywhere in the codebase. For an app built for people with a speech disability, accessibility is table stakes and reviewers are attentive to it in this category. Run VoiceOver over the main flows and test at the largest Dynamic Type size — in particular the score ring and the reading view, where fixed frames in the storyboards suggest text will clip.

---

## 7. Pre-submission checklist

### Code
- [ ] Sign in with Apple capability enabled; entitlements file exists and is referenced by `CODE_SIGN_ENTITLEMENTS`
- [ ] Apple button on both Login and Sign Up, at or above Google's prominence
- [ ] Apple sign-in creates a working account and syncs identically to Google
- [ ] Apple's one-time name is captured and persisted on first authorization
- [ ] Delete Account reachable from Settings in ≤3 taps, for accounts **and** guests
- [ ] Deletion removes: `auth.users`, all 12 tables, three local databases, Documents media, UserDefaults incl. `deviceId`, keychain JWT
- [ ] Apple token revoked on deletion — verified via Settings → Sign in with Apple on device
- [ ] Explicit "Account Deleted" confirmation shown
- [ ] `MockHomeScreen.swift` deleted and its `AppDelegate` call removed
- [ ] `SessionDiagnosticsViewController` gated behind `#if DEBUG`
- [ ] Lorem ipsum cleared from Reading and Conversation storyboards
- [ ] Privacy Policy, Terms, and Contact Support rows added to Settings
- [ ] Medical disclaimer visible on first launch and in About
- [ ] Purpose strings rewritten
- [ ] Groq key moved behind an Edge Function; Gemini key deleted; both rotated
- [ ] `.gitignore` covers `Stuttering App/AppSecrets.swift`
- [ ] RLS confirmed enabled with `auth.uid() = user_id` policies on all 12 tables
- [ ] `ITSAppUsesNonExemptEncryption = NO`
- [ ] Build number bumped (`CURRENT_PROJECT_VERSION` is still `1`)

### App Store Connect
- [ ] Privacy policy URL set
- [ ] App Privacy questionnaire matches `PrivacyInfo.xcprivacy` exactly
- [ ] Screenshots re-shot from a real build showing the Apple button — **not** `-MockHome`
- [ ] Demo account in App Review Information, pre-confirmed, with data in it
- [ ] Screen recording of the full deletion flow, captured on a physical device, in the Notes field
- [ ] Description free of "therapy", "treatment", "diagnosis", "clinically proven"
- [ ] Age rating reviewed — user-generated audio/video and an LLM conversation partner both affect it

### Reply to App Review
Once resubmitted, reply on both open threads:

> **4.8:** Sign in with Apple has been added to both the sign-in and sign-up screens, presented at equal prominence to Google Sign-In. It is available to all users as a primary account method, with full name and email as the only requested scopes and Hide My Email supported.
>
> **5.1.1(v):** Account deletion is now available at Settings → Delete Account, reachable in three taps from the home screen. It permanently deletes the account record, all cloud data, and all on-device data, and revokes the Sign in with Apple token via Apple's REST API. A screen recording of the complete flow on a physical device is attached in App Review Information.

---

## 8. Open questions for you

1. **Is RLS on?** I can't verify this from the codebase and it is the single highest-consequence unknown here.
2. **Is email confirmation enabled in Supabase?** It changes the sign-up flow and what the review demo account needs.
3. **Do you have a privacy policy and terms drafted?** If not, they're on the critical path — everything else can be built in parallel, that can't.
4. **Is the bundled 464 MB Whisper model still load-bearing**, given Apple's recogniser is now the primary transcript source? Dropping it would improve launch time, download size, and review turnaround at once.
5. **Should Apple and Google identities sharing an email be linked or kept separate?** This needs a decision before Apple sign-in ships, because changing it later strands accounts.
