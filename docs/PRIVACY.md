# Spasht — Privacy Policy

**Draft — not yet reviewed.** See `docs/README.md` for what still needs filling in and checking before this is published.

**Last updated:** _[publication date]_
**Applies to:** Spasht for iOS

---

## The short version

- Your **voice recordings never leave your device.** Speech is transcribed on your iPhone, and the audio is deleted as soon as the session is analysed.
- Your **video diary entries and Story Cubes recordings stay on your device.** They are never uploaded.
- If you create an account, your **practice results** — scores, streaks, which words you found difficult — sync to our servers so you don't lose them when you change phones. So does your **profile photo**, if you add one.
- **AI coaching is opt-in.** Spasht asks before sending anything to its AI provider, Groq, and you can turn it off at any time in Settings.
- **Guest mode keeps everything on your device.** Nothing a guest does leaves the phone — no account, no cloud storage, and no AI features, which require an account.
- We do not sell your data, we do not advertise to you, and we do not track you across other apps or websites.
- You can **delete your account and everything in it from inside the app**, at any time.

---

## 1. Who we are

Spasht is operated by _[legal entity name]_, _[registered address]_.

For anything in this policy, contact us at **_[privacy contact email]_**.

## 2. What we collect

### 2.1 Account information

If you create an account:

| Data | Why | Where it goes |
|------|-----|---------------|
| Email address | To identify your account and let you sign back in | Our authentication provider (Supabase) |
| First name | To address you in the app | Supabase |
| Phone number *(optional)* | Only if you choose to add it to your profile | Supabase |
| Profile photo *(optional)* | Only if you choose to add one. Stored so it survives reinstalling the app or signing in on another iPhone | Supabase Storage, in a private folder only your account can read |

If you sign in with **Apple** or **Google**, we receive your name and email address from them, and nothing else. If you use Apple's **Hide My Email**, we only ever see the relay address Apple generates — we never learn your real one.

**Guest mode collects none of this.** A guest account is identified by a random identifier generated on your device. It is not linked to you and never leaves the device.

### 2.2 Practice data

When you use Spasht we record what happened in each session:

- Reading sessions: fluency score, accuracy, and counts of blocks, repetitions, prolongations and misread words
- Which specific words and letter sounds you found difficult
- Exercise and conversation session history
- Daily tasks, goals, streaks, awards, and your practice journey

With an account, this syncs to our servers. In guest mode it stays in a database on your phone.

### 2.3 Audio and video — the important part

**Reading and practice sessions.** Spasht records audio while you read so it can measure your fluency. That audio is written to a temporary file on your device, analysed on your device, and **deleted when the session ends**. It is never uploaded.

**Speech recognition runs entirely on your iPhone.** Spasht uses Apple's on-device speech recogniser, configured to require on-device processing, together with a speech model bundled inside the app. No audio is sent to Apple, to us, or to anyone else.

**Video diary and Story Cubes.** Recordings you make in these features are saved in Spasht's private storage on your device. They are **never uploaded**, and only you can see them. They are included in your device backup if you back your iPhone up, and they are deleted when you delete your account or the app.

### 2.4 What we do not collect

We do not collect your location, contacts, health records, browsing history, or advertising identifiers. We never access your photo library: when you choose a profile photo, iOS hands Spasht only the one photo you pick. We do not track you across other apps or websites, and we do not use your data for advertising.

## 3. Third parties we share data with

### 3.1 Supabase — data storage and sign-in

Account information and practice data are stored with **Supabase**, our backend provider. They store this on our behalf and do not use it for their own purposes.
_[Supabase region / hosting location — fill in]_

### 3.2 Groq — coaching text

Spasht can use **Groq**, a third-party AI provider, to write the encouraging feedback you see after a session and to power the conversation practice partner.

**Nothing is sent to Groq unless you allow it.** Spasht asks when you first reach the home screen after signing in, explaining exactly what would be sent, and you can change your answer at any time in **Settings → AI Coaching**. On iPhones with Apple Intelligence, Spasht tries Apple's on-device model first, and that never leaves your phone.

If you allow it, two things are sent:

- **After a practice session:** aggregated numbers from that session — your fluency score, the percentage of blocks and repetitions, and up to five words you found difficult. Your name, email, and account identifier are **not** included.
- **During conversation practice:** the text of what you said, transcribed on your device, along with the recent conversation so the partner can reply sensibly. **Audio is never sent** — only the transcript.

**These features require an account and your permission.** In guest mode, or if you say no, nothing is sent to Groq. The app writes feedback itself instead, and conversation practice is available only where it can run on your iPhone.

_[Confirm and state Groq's data-retention terms for your account tier.]_

### 3.3 Apple and Google — sign-in only

If you choose to sign in with Apple or Google, they handle the sign-in and tell us your name and email address. Their own privacy policies govern what they do with the fact that you signed in.

### 3.4 The same protection, wherever your data goes

Every provider we share data with — Supabase, Groq, Apple and Google — is required to protect it to at least the standard described in this policy, and may use it only to provide its service to us.

### 3.5 We do not sell your data

We have never sold personal data and do not share it for advertising or cross-context behavioural advertising.

## 4. How long we keep it

We keep your account data and practice history for as long as your account exists. When you delete your account, it is removed as described in section 5.

Session audio is deleted as soon as the session has been analysed — typically within seconds.

## 5. Deleting your account and your data

You can delete your account from inside the app: tap your **profile picture** on the home screen, then **Profile → Delete Account**.

This permanently deletes:

- your account record and sign-in credentials
- all practice history stored on our servers
- all data stored on your device, including video diary and Story Cubes recordings
- your profile photo, on our servers and on your device
- your Sign in with Apple authorisation, if you used it

Deletion is immediate and cannot be undone. We do not keep a backup copy of a deleted account.

In **guest mode** there is no account and nothing is stored on our servers. Everything lives inside the app on your device, and deleting the app deletes all of it.

## 6. Your rights

Depending on where you live, you may have the right to access, correct, export, or delete your personal data, to object to or restrict how we use it, and to complain to your local data protection authority.

You can exercise most of these directly in the app — your profile, photo and AI Coaching choice are all in Settings, and deletion is on the Profile screen. For anything else, write to **_[privacy contact email]_** and we will respond within _[30 days / your chosen period]_.

_[If you have users in the EEA or UK, state your lawful basis for processing — likely performance of a contract for account and practice data. Confirm with counsel.]_

## 7. Children

Spasht is not directed at children under _[13 / 16 — decide and align with your App Store age rating]_, and we do not knowingly collect personal data from them. If you believe a child has created an account, contact us and we will delete it.

_[Stuttering commonly begins in childhood, so this is a realistic scenario rather than boilerplate. Decide deliberately whether under-18s are in scope, and align this section, your App Store age rating, and any parental-consent flow.]_

## 8. Security

Data in transit is encrypted with HTTPS. Data stored with Supabase is protected by row-level access rules so that your records are readable only by your own account. Data on your device is protected by your iPhone's own encryption.

No system is perfectly secure, and we cannot guarantee absolute security.

## 9. Changes to this policy

If we change this policy materially we will update the date at the top and notify you in the app before the change takes effect.

## 10. Contact

**_[privacy contact email]_**
_[legal entity name and registered address]_

---

## Important — this is not medical advice

Spasht is a practice tool, not a medical device. It does not diagnose, treat, or provide a clinical assessment of stuttering. Its measurements are estimates produced by software and should not be relied on as a clinical result. For assessment or therapy, please see a qualified speech-language pathologist.
