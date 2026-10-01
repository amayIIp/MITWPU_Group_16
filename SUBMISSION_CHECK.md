# Spasht — Pre-Resubmission Check

**Last updated:** 24 September 2026
**Build:** Release `** BUILD SUCCEEDED **`, no warnings in app code. Build number is `2`.

## Where things stand

All the code work is done. What's left is three inputs from other people: the Apple key, the Developer portal switch, and the hosted privacy policy. Then there are the App Store Connect steps. Each one is listed below with the exact thing to do.

| # | Item | Guideline | Status |
|---|------|-----------|--------|
| 1 | Sign in with Apple entitlement restored | 4.8 | ✅ Code done · ⏳ portal switch (step A) |
| 2 | Apple token revocation: bundle ID fixed, one-command setup script | 5.1.1(v) | ✅ Code done · ⏳ Apple key (step B) |
| 3 | AI consent before any data goes to Groq | 5.1.2(i) | ✅ Done and tested in the simulator |
| 4 | Privacy policy and terms | 5.1.1(i) | ✅ Drafts updated · ⏳ hosting (step C) |
| 5 | Profile-photo privacy: manifest, camera prompt, policy | 5.1.1 / 5.1.2 | ✅ Done |
| 6 | Build number | — | ✅ Set to `2` |
| 7 | App Store Connect submission items | 2.1 / 4.8 / 5.1.1(v) | ⏳ Step E |

---

## Final steps, in order

### A. Apple Developer portal: turn on Sign in with Apple (whoever holds the team account)

1. developer.apple.com → Certificates, Identifiers & Profiles → **Identifiers → `com.spasht.app`** → tick **Sign in with Apple** → Save.
2. **Keys → +** → name it "Spasht SIWA" → tick **Sign in with Apple** → Configure → primary App ID `com.spasht.app` → Register → **download the `.p8`**. Apple lets you download it only once. Note the **Key ID**.
3. Supabase dashboard → Authentication → Providers → **Apple** → enable → **Client IDs = `com.spasht.app`**.
4. Optional but recommended: Services → **Sign in with Apple for Email Communication** → register the domain your password-reset emails are sent from. Without it, Hide My Email users never receive reset emails.

> Until step A.1 is done, **building to a physical iPhone will fail to sign**, because the entitlement is back in the project. That is expected. Don't remove the entitlement to get around it; that is what broke Sign in with Apple last time. Simulator builds are unaffected.

### B. Supabase: turn on Apple token revocation (one command)

From the repo root, with the Key ID and the `.p8` from step A.2:

```bash
./supabase/set-apple-secrets.sh ABCDE12345 ~/Downloads/AuthKey_ABCDE12345.p8
```

This sets `APPLE_TEAM_ID`, `APPLE_CLIENT_ID=com.spasht.app`, `APPLE_KEY_ID` and `APPLE_PRIVATE_KEY`, redeploys `apple-register-code` and `delete-account`, and checks that all four secrets saved. `*.p8` is now git-ignored.

> **Do step B before anyone signs in with Apple for real.** Apple's authorization code is captured only at sign-in and expires in about 5 minutes. A Sign in with Apple account created before the secrets exist can never have its token revoked. Test accounts don't matter, but delete them and recreate them after step B.

### C. Privacy policy and terms: publish and switch on

1. Fill the `_[…]_` blanks in [docs/PRIVACY.md](docs/PRIVACY.md) and [docs/TERMS.md](docs/TERMS.md): legal entity, contact email, Supabase region, Groq retention, **minimum age**, jurisdiction. The photo, phone number and AI-consent wording is already updated.
2. Host both pages. GitHub Pages or Notion is fine.
3. In [LegalLinks.swift](Stuttering%20App/Model/Onboarding/LegalLinks.swift), change these three lines:
   ```swift
   static let privacyPolicy = URL(string: "https://<your-real-url>/privacy")!
   static let termsOfUse    = URL(string: "https://<your-real-url>/terms")!
   static let supportEmail  = "<a real inbox>"
   static let isConfigured  = true
   ```
   While `isConfigured` is `false`, the links show "Not Available Yet". A reviewer who taps one will reject the app, so **don't upload without flipping it**.

### D. Device check before archiving

- [ ] In Xcode, check **Signing & Capabilities → Bundle Identifier = `com.spasht.app`**. Today it was changed by accident twice (to `-r` and to `com.spasht.app896`), probably stray keystrokes in the build-settings field. Check it right before you archive.
- [ ] Sign in with Apple on a physical iPhone, once with **Share My Email** and once with **Hide My Email**.
- [ ] Supabase → `apple_tokens` has a row for that user.
- [ ] Delete that account. Then **iPhone Settings → [your name] → Sign in with Apple** should no longer list Spasht.
- [ ] Forgot-password works end to end.

### E. App Store Connect

- [ ] **Screen recording on a physical iPhone**: sign in with the demo account → profile picture → Profile → Delete Account → type DELETE → "Account Deleted". Put it in App Review Information → **Notes**. Apple asked for this explicitly.
- [ ] **Demo account**: email and password, **already email-confirmed**, with some practice data in it.
- [ ] **Screenshots re-shot** from a real build showing the Apple button on the sign-in screen. Take them from a build that includes the 24 Sep navigation-bar fix (`PageBarAppearance.installGlobally()`). Older builds show a hard white line under the bar on iOS 26 and later.
- [ ] **App Privacy questionnaire** matches `PrivacyInfo.xcprivacy`: Email, Name, **Photos or Videos**, User ID, Other User Content, **Health**, Product Interaction. All linked to the user, none used for tracking, all for App Functionality. **Phone Number is no longer collected**, so untick it if it was ticked.
- [ ] Privacy policy URL and support URL filled in.
- [ ] Age rating matches the minimum age chosen in step C.
- [ ] Description avoids "therapy", "treatment", "diagnosis" and "clinically proven".
- [ ] Reply on both review threads. Text you can paste is below.

**Reply text:**

> **Guideline 4.8:** Sign in with Apple is now offered on both the sign-in and sign-up screens, directly above Google Sign-In and at the same size. It is a full primary-account option: we request only name and email, Hide My Email is supported, and we do no advertising tracking.
>
> **Guideline 5.1.1(v):** Account deletion is available in the app: tap the profile picture on the home screen → Profile → Delete Account. It permanently deletes the account, all data on our servers and on the device, and revokes the Sign in with Apple token through Apple's REST API. A screen recording of the full flow on a physical device is in the App Review notes.
>
> Also, AI features ask for the user's permission before any data is sent to our AI provider, Groq, and the choice can be changed in Settings → AI Coaching.

---

## What changed in this pass

**Guideline 5.1.2(i): AI consent** (new [AIConsent.swift](Stuttering%20App/Model/Networking/AIConsent.swift))
- `GroqService.isAvailable` now requires an account **and** consent, and every Groq call goes through it. Nothing is sent to Groq until the user taps **Allow**.
- A signed-in user is asked once on Home, after the medical disclaimer and before the notification prompt. The prompt names Groq, says exactly what is sent, and says voice recordings are never sent.
- **Settings → AI Coaching** has a switch with the same explanation beneath it. Switching it on shows the disclosure again; "Not Now" leaves it off.
- On the Conversation tab, the prompt appears only when conversation practice would actually use Groq. On iPhones with Apple Intelligence it runs on-device.
- If the user declines, every other feature falls back cleanly to on-device or built-in text.
- The saved choice is per account and is removed on account deletion.
- Tested in the simulator: prompt → Allow → switch on → switch off → switch on shows the disclosure → Not Now leaves it off. That testing caught a crash in the new Settings section (a missing header/footer view override), which is fixed.

**Sign in with Apple and revocation**
- `Stuttering App.entitlements` has `com.apple.developer.applesignin = [Default]` again.
- `_shared/apple.ts` and the Info.plist URL type now use `com.spasht.app` instead of `com.spasht.app1`.
- Added [supabase/set-apple-secrets.sh](supabase/set-apple-secrets.sh) and git-ignored `*.p8`.

**Profile photos**
- `PrivacyInfo.xcprivacy` now declares **Photos or Videos** and no longer lists **Phone Number**, which nothing in the app collects.
- New camera prompt: *"Spasht uses the camera for your video diary, which stays on this device, and to take a profile photo if you choose to add one."*
- `docs/PRIVACY.md` covers the profile photo, opt-in AI and the current deletion path. The out-of-date guest "Delete All My Data" text is removed. `docs/TERMS.md` has the corrected deletion path.

**Housekeeping**
- `CURRENT_PROJECT_VERSION = 2`.
- Fixed three iOS 26 deprecation warnings and an unused `try?`.

---

## Already fixed before this pass ✅

- Apple button on both auth screens, above Google and the same size. Apple's one-time name is saved, and Apple users aren't asked for their name again.
- Full account deletion flow (3 taps, typed confirmation, "Account Deleted" confirmation). It removes all 12 tables, the avatar storage, `auth.users` and all local data.
- Groq key moved out of the app into the `groq-chat` Edge Function. `AppSecrets.swift` is git-ignored.
- Fake home screen removed, diagnostics screen debug-only, no lorem ipsum left.
- Medical disclaimer on first launch.
- Legal links in Settings and on the auth screens.
- Export compliance key set, app icon has no alpha channel, no user IDs in logs.

## Worth doing, not blockers

- Delete `LoginViewController.swift`, `SignUpViewController.swift` and their storyboard scenes, which are no longer used.
- Guideline 1.4.1 asks apps to disclose the methodology behind health measurements. A short "How is this measured?" note on the result screen would strengthen the fluency score.
- Accessibility pass (VoiceOver, largest Dynamic Type).
- Deployment target iOS 26.0 limits who can install the app. See PHASES.md, Q7.
