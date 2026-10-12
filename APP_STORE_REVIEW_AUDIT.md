# Spasht — App Store Review Audit

**Date:** 4 October 2026
**Build audited:** `main` @ `fbd337f`, bundle `com.spasht.app`, version 1.0 (2) — Release `** BUILD SUCCEEDED **`
**Against:** the current [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), plus App Store Connect's current [age-rating questionnaire](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions) and [regulated medical device declaration](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/)

**How this was done.** The guidelines were re-read today rather than recalled. Every finding below was checked against the code, the build, or the live website — not against earlier notes, several of which turned out to be out of date (the bundle ID, the app icon, and the published privacy policy all differed from what earlier documents said).

---

> ### Status — 5 October 2026
>
> The four likely rejections are **fixed in code and verified in the simulator**:
>
> - **#1 Privacy policy** — corrected text is in [docs/PRIVACY_PUBLISHED.md](docs/PRIVACY_PUBLISHED.md), laid out in the live page's own section order. **It still has to be pasted onto the Netlify site** — that site isn't in this repo. Also found: the profile screen's "Mobile No" field does sync, so Phone Number is back in the privacy manifest and must be **ticked** in App Store Connect.
> - **#2 Severity grade** — "mild/moderate" removed from the result screen and from the AI prompt; ⓘ *How is this measured?* sheet added, describing the real method, its limits, and the disclaimer.
> - **#3 Microphone dead end** — *Skip the Test* on both permission alerts. Verified: deny → skip → Home → disclaimer → notification prompt, in that order.
> - **#5 Treatment claim** — tagline is now "Practice speaking. Build confidence."
>
> #4 (Sign in with Apple on device) is still with the account holder, and #6–#13 are unchanged.

## Verdict

The two original rejections — **4.8** (Sign in with Apple) and **5.1.1(v)** (account deletion) — are fixed in code. What remains for those two is the account holder's setup on a real device.

But this pass found **four things likely to cause a new rejection**, none of which were in the earlier reports:

1. The **published privacy policy** describes features that no longer exist and is missing three statements 5.1.1(i) requires word-for-word.
2. The reading result screen **grades stuttering as "mild" or "moderate"** with no methodology disclosed — the exact pattern 1.4.1 says Apple will reject.
3. A new account that **declines the microphone is stuck in onboarding forever** — and so can never reach Delete Account. Reviewers routinely tap "Don't Allow".
4. The **first screen says "Reduce stuttering"**, which the app's own disclaimer contradicts.

All four are small fixes. The first and fourth are copy changes; the second and third are a few hours each.

---

## Findings at a glance

| # | Finding | Guideline | Risk | Effort |
|---|---------|-----------|------|--------|
| 1 | Live privacy policy is out of date and missing required statements | 5.1.1(i), 5.1.2(i), 2.3 | 🔴 Likely rejection | 1 hour |
| 2 | Clinical severity grade with no methodology | 1.4.1 | 🔴 Likely rejection | Half a day |
| 3 | Denying the microphone dead-ends onboarding — and blocks account deletion | 5.1.1(iv), 5.1.1(v), 2.1 | 🔴 Likely rejection | 1–2 hours |
| 4 | Sign in with Apple not yet live end to end | 4.8, 5.1.1(v), 2.1 | 🔴 Blocker until done | Account holder |
| 5 | "Reduce stuttering" on the first screen | 1.4.1, 2.3.7 | 🟠 Possible rejection | 5 minutes |
| 6 | AI conversation partner has no report action or output moderation | 4.7.1, 1.2 | 🟠 Possible rejection | Half a day |
| 7 | Minimum age undecided; policy says children may use the app | 5.1.4, 2.3.6 | 🟠 Possible rejection + legal | 1–2 hours |
| 8 | Healthcare-adjacent app from an individual developer | 5.1.1(ix) | 🟠 Confirm | — |
| 9 | Regulated medical device declaration (new App Store Connect field) | — | 🟡 Required step | 5 minutes |
| 10 | Updated age-rating questionnaire | 2.3.6 | 🟡 Required step | 10 minutes |
| 11 | Review notes must describe features specifically | 2.3.1(a) | 🟡 Required step | Draft below |
| 12 | Guest data deletion removed | 5.1.1(v) | 🟢 Low | — |
| 13 | iPhone-only app is still reviewed on iPad | 2.4.1 | 🟢 Low | 30 minutes |

---

## 🔴 1. The published privacy policy is out of date and incomplete

**Guideline 5.1.1(i)** requires the policy to *"clearly and explicitly"*:

> - Identify what data, if any, the app/service collects, how it collects that data, and all uses of that data.
> - Confirm that any third party with whom an app shares user data … will provide the same or equal protection of user data as stated in the app's privacy policy …
> - Explain its data retention/deletion policies and describe how a user can revoke consent and/or request deletion of the user's data.

**Guideline 5.1.2(i)** adds: *"You must clearly disclose where personal data will be shared with third parties, including with third-party AI, and obtain explicit permission before doing so."*

### What the live page at `spashtapp.netlify.app/#privacy-policy` says today

| The page says | The app actually does |
|---|---|
| Groq "applies in guest mode too; it's the only thing that leaves the device when you're a guest" | Guests get **no** AI at all — `GroqService.isAvailable` is `isAccountMode && AIConsent.isGranted` |
| In guest mode, "the profile icon → Delete All My Data" | That button was **removed** on 18 September. A reviewer following the policy finds nothing |
| Delete Account is at "Profile → Settings → Delete Account" | It's profile icon → **Profile** → Delete Account, at the bottom of that screen |
| "We're finalizing a minimum age" | A published statement that a policy decision is unmade — 2.1 asks for no temporary content |

### What it's missing

| Required by 5.1.1(i) / 5.1.2(i) | Live page | `docs/PRIVACY.md` in the repo |
|---|---|---|
| Third parties provide **equal protection** | ✗ | ✗ |
| **Retention** policy | ✗ | ✓ |
| How to **revoke consent** (Settings → AI Coaching) | ✗ | ✓ |
| AI sharing is **opt-in**, with explicit permission | ✗ — never mentioned | ✓ |

The repo draft is newer than what's published. It was updated on 24 September for AI consent and profile photos, but never pushed to the site, and it still has 13 `_[…]_` placeholders.

### Fix

1. Add the missing sentence to `docs/PRIVACY.md`, in the third-parties section:

   > Each provider we share data with — Supabase for storage and sign-in, Groq for AI-generated text, and Apple and Google for sign-in — is bound to protect your data to the same standard as this policy, and may use it only to provide its service to us.

2. Fill the placeholders that matter: entity name, contact address, minimum age (see #7), Groq retention.
3. Publish it over the current Netlify content.
4. State the deletion path exactly: *tap your profile picture on the home screen → Profile → Delete Account*.

Reviewers do read the policy against the app. A policy that describes a button that isn't there is the kind of mismatch that gets cited.

---

## 🔴 2. A clinical severity grade with no disclosed methodology

**Guideline 1.4.1:**

> Medical apps that could provide inaccurate data or information, or that could be used for diagnosing or treating patients may be reviewed with greater scrutiny.
> - Apps must clearly disclose data and methodology to support accuracy claims relating to health measurements, and **if the level of accuracy or methodology cannot be validated, we will reject your app.**
> - Apps should remind users to check with a doctor in addition to using the app and before making medical decisions.

### What a user sees

After a reading session, [ReadingResultViewController2.swift:598](Stuttering%20App/View/Reading/ReadingResultViewController2.swift:598) shows, for example:

> **8.3% of syllables stuttered — moderate.** Rates are a share of the 142 words we could assess.

The severity word comes from fixed bands in [StutterAnalyzer.swift:577](Stuttering%20App/Model/Reading/StutterAnalyzer.swift:577) — under 7% "mild", under 12% "moderate", above that "severe" (shown as "high this session"). Percent syllables stuttered banded into mild/moderate/severe is the shape of a clinical severity assessment.

And:

- **No methodology is disclosed anywhere** in the app — no "how is this measured?", nothing explaining that it's automated speech recognition counting repetitions, blocks and prolongations, nothing on what it can get wrong.
- **The measurement hasn't been validated on real speakers.** The project's own Read Aloud audit records that the acoustic thresholds have only ever been checked against synthetic signals.
- **The medical disclaimer appears once**, on first launch, and can never be seen again (`AppState.hasSeenMedicalDisclaimer`). 1.4.1 asks apps to *remind* users.

### A correction to my earlier report

In Phase 4 I wrote that the result-screen copy was "already reasonable" and that "no rewording was needed". That was wrong. I checked the confidence hedging and missed that the same line attaches a severity grade. The hedging is good; the severity label is the problem.

### Fix

Either of these closes it. The first is stronger.

- **Drop the clinical bands.** Report the percentage and compare it to the user's **own** history — "smoother than your last five sessions" — rather than to a clinical scale. Nothing then reads as a diagnosis.
- **Or keep them, and disclose.** Add an ⓘ next to the score that opens a short "How is this measured?" sheet covering: on-device speech recognition, what counts as a repetition, block or prolongation, that the result is an automated estimate that can be wrong in either direction, that it isn't a clinical assessment, and a pointer to a speech-language pathologist.

In both cases, put the disclaimer somewhere permanently reachable — the bottom of that sheet, or Settings → About.

The ⓘ sheet is worth adding even if you drop the bands. It's the single most direct answer to 1.4.1.

---

## 🔴 3. Denying the microphone dead-ends onboarding

**Guideline 5.1.1(iv):** *"Apps must respect the user's permission settings and not attempt to manipulate, trick, or force people to consent to unnecessary data access … Where possible, provide alternative solutions for users who don't grant consent."*

### What happens

1. A new user signs up — any provider.
2. Onboarding reaches the speech test. [OnboardingInstructionsViewController.swift:208](Stuttering%20App/View/Onboarding/OnboardingInstructionsViewController.swift:208) requests the microphone.
3. The user taps **Don't Allow**.
4. An alert offers **Settings** or **Cancel**. Cancel leaves them on the same screen.

There is no skip anywhere in onboarding. The only way forward is to grant the permission in iOS Settings.

### Why it's worse than it looks

Onboarding runs *after* account creation. So this user has an account, holds data on the server, and **cannot reach Delete Account**, which lives behind the home screen they can't get to. A 5.1.1(iv) issue becomes a 5.1.1(v) issue.

App Review routinely taps "Don't Allow" to see what happens.

### Fix

Add **Skip for now** on the speech-test screen. It finishes onboarding with default practice settings, and the user can take the speech test later from Read Aloud. Exercises, awards, settings and account deletion don't need the microphone.

The microphone is genuinely core to the app, and Apple accepts that — the *reading* feature can ask for it again when it's used. What it won't accept is the whole app being unreachable.

---

## 🔴 4. Sign in with Apple isn't live end to end yet

The code is done and verified: the entitlement is committed, the button sits on both auth screens above Google at the same size, and the bundle ID is `com.spasht.app` in both configurations. What's left belongs to the account holder, and is laid out step by step in [HANDOVER.md](HANDOVER.md):

- `DEVELOPMENT_TEAM` is still `C2N3Q4846H`, the developer's personal team. It must be the shipping team.
- The three `APPLE_*` secrets aren't set in Supabase, so deletion can't revoke Apple tokens yet.
- It hasn't run on a physical device. The simulator can't do Sign in with Apple at all.

This was the original 4.8 rejection, so it has to work on the reviewer's device first time. **Run test 6 in HANDOVER.md** — delete an Apple-created account, then check Spasht has disappeared from iOS Settings → Sign in with Apple — before you submit.

---

## 🟠 5. "Reduce stuttering" on the first screen

The landing screen ([Onboarding.storyboard:90](Stuttering%20App/View/Onboarding/Onboarding.storyboard)) reads:

> **Fluency starts here.**
> Reduce stuttering. Build confidence.

The medical disclaimer, a few screens later, reads: *"It does not diagnose or **treat** stuttering."*

"Reduce stuttering" is a treatment-outcome claim, it's the first thing a reviewer sees, and the app contradicts it itself. 1.4.1 reviews medical claims with greater scrutiny, and 2.3.7 bars unverifiable product claims in subtitles — so carry the same fix into App Store Connect.

**Fix:** *"Practice speaking. Build confidence."* Use matching wording in the subtitle and description, and avoid "reduce", "treat", "therapy", "cure", "diagnose" and "clinically proven" throughout.

---

## 🟠 6. The AI conversation partner has no report action or moderation

**Guideline 4.7** names chatbots explicitly — *"Apps may offer certain software that is not embedded in the binary, specifically … chatbots"* — and **4.7.1** requires that such software:

> include a method for filtering objectionable material, a mechanism to report content and timely responses to concerns, and the ability to block abusive users

Whether 4.7 covers a first-party LLM feature is arguable; it was written with third-party bots in mind. But 4.7.1's three requirements are the standard App Review applies to AI chat, and Spasht's conversation partner meets none of them:

- **No way to report a reply.** There's no report action anywhere in `View/Conversation` or `ViewModel/Conversation`.
- **No output moderation.** The `groq-chat` function forwards the model's reply untouched.
- **The system prompt guards two things only** — refusing medical advice, and resisting prompt injection. Nothing on sexual, violent or self-harm content.

That last point matters for this audience beyond the guideline. People who stutter have markedly higher rates of social anxiety, and a voice conversation partner is exactly where someone might say something worrying. As written, the model has no instruction for that.

**Fix (half a day):**

1. Add to the persona's safety rules: decline sexual, violent or hateful content; if the user mentions self-harm or a crisis, respond with care, encourage them to talk to someone they trust, and give a crisis line.
2. Add a **Report** action on each AI reply that writes the turn to a Supabase `ai_reports` table, or opens the support page pre-filled. Say on the support page that reports are reviewed.
3. *(Optional, stronger)* Run each reply through a moderation model on Groq inside `groq-chat` before returning it.

"Block abusive users" doesn't apply — there are no other users.

---

## 🟠 7. The minimum age is still undecided

The published policy says: *"Stuttering often begins in childhood, so Spasht may be used by children … We're finalizing a minimum age."*

That publicly acknowledges children may create accounts — which collect an email address, voice-derived measurements, a profile photo, and conversation transcripts sent to an AI. Under COPPA in the US, collecting any of that from under-13s needs verifiable parental consent. **Guideline 5.1.4** requires apps that do so to *"comply with all applicable children's privacy statutes"*.

**Fix — and it lines up with #10:**

- **Accounts are 13+.** Add a single "I'm 13 or older" confirmation on Create Account, or a birth-year field.
- **Guest mode stays open to everyone.** It collects nothing and sends nothing anywhere, so it's a clean option for younger users.
- The age rating will be **13+** anyway once the questionnaire is answered honestly (#10), so the two agree.
- Update the policy and terms to say so, replacing "We're finalizing".

---

## 🟠 8. A healthcare-adjacent app from an individual developer

**Guideline 5.1.1(ix):** *"Apps that provide services in highly regulated fields (such as … healthcare …) or that require sensitive user information should be submitted by a legal entity that provides the services, and not by an individual developer."*

Spasht positions itself as a practice tool, not healthcare, and the disclaimer says so. But it collects health data (declared as **Health** in the privacy manifest) about a speech disorder.

**Action:** confirm the Apple Developer account that will submit belongs to an **organisation** — the university, for instance — not an individual. If it's an organisation, this is fine. If it's an individual, fixing #2 and #5 matters more, because the less the app looks like healthcare, the less this guideline applies.

---

## 🟡 9. Declare regulated medical device status

A [new App Store Connect requirement](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/). Apps available in the **US, EU/EEA or UK** must declare whether they're a regulated medical device if their primary or secondary category is **Health & Fitness** or **Medical**, *or* they answer "Frequent" to Medical or Treatment Information.

Spasht will almost certainly be in Health & Fitness.

**Answer: No.** It's consistent with the disclaimer. Keep everything else consistent with that answer too. In the EU, software whose intended purpose is to *measure or monitor* a medical condition can fall under the Medical Device Regulation, and intended purpose is judged from what you claim. That's one more reason to fix #2 and #5: an app that grades stuttering severity and promises to reduce it is making the claims that would make "No" hard to defend.

---

## 🟡 10. Answer the updated age-rating questionnaire

Apple [overhauled the age ratings](https://developer.apple.com/news/?id=ks775ehf), adding 13+, 16+ and 18+, and responses to the new questions were due by 31 January 2026.

My recommended answers, from the [definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions):

| Question | Answer | Why |
|---|---|---|
| Health or Wellness Topics | **Yes** → 9+ | Practice routines and daily goals |
| Medical or Treatment Information | **Infrequent** → 13+ | The exercises — gentle onset, airflow, light contacts, prolongation — are standard stuttering-management techniques, which is "guidance around the management of medical conditions" |
| Messaging and Chat | **No** | Defined as users communicating *with one another*. The AI partner isn't another user |
| User-Generated Content | **No** | Nothing is distributed to other users |
| Unrestricted Web Access | **No** | `SFSafariViewController` opens three fixed pages; there's no browsing |
| Advertising | **No** | |
| Parental Controls / Age Assurance | **No** | Unless you add an age gate for #7 — then Age Assurance is **Yes** |

**Result: 13+**, which matches the minimum age in #7.

"Medical or Treatment Information" is a judgment call; it's the honest reading. Don't answer **Frequent** without reason — that alone makes the rating 16+ and triggers the medical device declaration in #9.

---

## 🟡 11. Review notes must describe features specifically

**Guideline 2.3.1(a):** *"All new features, functionality, and product changes must be described with specificity in the Notes for Review section … (generic descriptions will be rejected)."*

**Guideline 2.1:** include a working demo account and keep the backend on.

Email confirmation is now on, so the demo account must be **confirmed in advance** or the reviewer can't sign in. Give it a few practice sessions so the progress screens aren't empty.

### Draft notes for App Review

> **Demo account:** `<email>` / `<password>` — already email-confirmed, with practice history.
>
> **Sign in with Apple (4.8):** offered on both the sign-in and sign-up screens, above Google and at the same size. We request only name and email; Hide My Email is supported; we do no advertising tracking.
>
> **Account deletion (5.1.1(v)):** tap the profile picture on the home screen → Profile → Delete Account → type DELETE. This permanently deletes the account, all server data and stored photos, all on-device data, and revokes the Sign in with Apple token through Apple's REST API. A screen recording on a physical device is attached.
>
> **AI features (5.1.2(i)):** post-session feedback and the conversation partner can use Groq, a third-party AI provider. Nothing is sent until the user explicitly allows it in a prompt that names Groq and what is shared; the choice can be changed in Settings → AI Coaching. Voice audio is never sent — speech is transcribed on the device. On iPhones with Apple Intelligence the conversation partner runs on-device and Groq isn't used. Guests have no AI features.
>
> **Guest mode:** "Continue as guest" on the welcome screen. Guest data never leaves the device.
>
> **Medical disclaimer (1.4.1):** shown before first use and from ⓘ on the result screen. Spasht is a practice tool, not a medical device, and the scores are automated estimates.
>
> **Permissions:** the microphone is needed for reading practice and is requested when first used. Users who decline can skip the speech test and use the rest of the app.

The last two paragraphs assume #2 and #3 are fixed. Edit them if not.

---

## 🟢 12. Guest data deletion was removed

Apple's [account deletion guidance](https://developer.apple.com/support/offering-account-deletion-in-your-app/) mentions "automatically generated accounts". The reasoning for removing the guest button is sound: guest data exists only in the app container, which iOS deletes with the app, and nothing is held on a server. Low risk. If a reviewer raises it, that's the answer.

## 🟢 13. iPhone-only apps are still reviewed on iPad

`TARGETED_DEVICE_FAMILY = 1`, so Spasht is iPhone-only — but **2.4.1** says iPhone apps should run on iPad where possible, and reviewers do launch iPhone apps on iPad in compatibility mode. Run it once on an iPad simulator, through onboarding to Home, and check nothing is cut off or crashes.

---

## Verified clean ✅

Checked directly in this pass:

| Area | Result |
|---|---|
| Bundle ID | `com.spasht.app` in Debug and Release |
| Sign in with Apple | Entitlement committed; button on both auth screens, above Google, same size |
| Account deletion | In-app, typed confirmation, completion alert; server rows, avatar storage, `auth.users` and Apple token revocation |
| AI consent (5.1.2(i)) | `GroqService.isAvailable` requires an account **and** consent; Settings → AI Coaching toggle |
| Permission strings | Every permission-gated API has one. Photos are picked with `PHPicker`, which needs none |
| Background modes (2.5.4) | None declared |
| Privacy manifest | Email, Name, Photos or Videos, User ID, Other User Content, Health, Product Interaction; tracking off |
| Required-reason APIs | App, WhisperKit and Supabase use only UserDefaults and file timestamps — both declared. No ITMS-91053 risk |
| Third-party SDK manifests | GoogleSignIn 9.2.0, AppAuth, GTMAppAuth, gtm-session-fetcher all ship them |
| App icon | Primary icon has no alpha (ITMS-90717). Dark and tinted variants have transparency, which is allowed |
| Export compliance | `ITSAppUsesNonExemptEncryption = NO` |
| Debug surfaces | Diagnostics screen and its gesture are `#if DEBUG` |
| Metadata hygiene | No lorem ipsum, "beta", other-platform mentions, or custom review prompts |
| Legal links (1.5) | Live; all three anchors exist; open in-app on the correct section |
| Build number | `2`. It must be higher than any build already uploaded |
| Ads, tracking, IAP | None |

## Couldn't verify from here

- **Crashes on a real device** (2.1). Run the whole app through TestFlight on at least two iPhones before submitting.
- **Sign in with Apple, Google and deletion on device** — needs the shipping team (#4).
- **The AI features against the live backend** while signed in, including on an Apple Intelligence device, where the on-device model has hung before.
- **Who owns the developer account** (#8).

---

## Suggested order

1. **Today, all copy:** #5 tagline · #1 privacy policy (add the protection sentence, fix guest and deletion text, publish) · #7 settle 13+
2. **This week, code:** #3 Skip for now · #2 ⓘ methodology sheet, drop or reword the bands · #6 report action and safety rules · #7 age confirmation on sign-up
3. **Account holder:** #4 HANDOVER.md, ending with test 6 on a physical iPhone
4. **App Store Connect:** #9 medical device "No" · #10 age rating · privacy label matching the manifest · #11 review notes, demo account and deletion screen recording · new screenshots
5. **Then submit**

---

## Sources

- [App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Age ratings values and definitions](https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions)
- [Updated age ratings in App Store Connect](https://developer.apple.com/news/?id=ks775ehf)
- [Declare regulated medical device status](https://developer.apple.com/help/app-store-connect/manage-app-information/declare-regulated-medical-device-status/)
- [Offering account deletion in your app](https://developer.apple.com/support/offering-account-deletion-in-your-app/)
