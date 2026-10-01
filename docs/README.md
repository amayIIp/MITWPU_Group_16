# Legal documents — status

Drafts of the two documents App Review and App Store Connect require. **Neither is ready to publish.**

| File | Status |
|------|--------|
| [PRIVACY.md](PRIVACY.md) | Draft — factually checked against the code, needs the blanks filled and a legal review |
| [TERMS.md](TERMS.md) | Draft — sections 8 and 9 are placeholders and need counsel |

## What these drafts are, and are not

The **factual claims are accurate as of 18 Sep 2026** — every statement about what data is collected, where it goes, and what stays on the device was checked against the source, not assumed. Specifically verified:

- All three speech-recognition sites set `requiresOnDeviceRecognition = true`, so "no audio is sent to Apple" is true (`DetailViewController.swift:472`, `VoiceViewModel.swift:355`, `TestViewController.swift:129`)
- Session audio is written to `FileManager.temporaryDirectory` and removed after analysis (`DetailViewController.swift:337`, `:376`)
- Video diary and Story Cubes files are written to Documents and never uploaded
- The post-session Groq payload carries aggregated metrics and up to five troubled words, with no name, email, or user ID (`InsightEngine.buildSessionPrompt`)
- The conversation feature sends transcribed text — never audio — to Groq (`VoiceViewModel.swift:542`)
- Account data is limited to email, first name, and an optional phone number (`UserProfile`)

**I am not a lawyer and this is not legal advice.** The drafts need review by someone who is, particularly on the children's-data question, the lawful basis for processing, and the liability and governing-law sections.

## Blanks to fill

- [ ] Legal entity name and registered address
- [ ] Privacy contact email and support contact email
- [ ] Supabase hosting region
- [ ] Groq data-retention terms for your account tier — confirm and state them
- [ ] Minimum age, decided once and used consistently in the privacy policy, the terms, and the App Store age rating
- [ ] Response window for data-subject requests
- [ ] Governing law and jurisdiction
- [ ] Publication date

## Decisions needed

**Minimum age.** Stuttering commonly begins in childhood, so under-18 users are a realistic audience rather than a theoretical one. Decide deliberately whether they are in scope. If they are, you likely need a parental-consent flow, and the App Store age rating and privacy label must match. This is the single most consequential open question in these documents.

**Lawful basis (EEA/UK).** Probably performance of a contract for account and practice data — confirm with counsel.

**Apple's EULA.** Either use [Apple's standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/) or include Apple's minimum terms in your own. See the note at the end of TERMS.md.

## Hosting

Both documents need public URLs before submission:

- The privacy policy URL is required metadata in App Store Connect
- Both are linked from Settings in the app (Phase 4)

GitHub Pages off this `docs/` folder is the cheapest option. If you do that, note that the repo is currently public — see Phase 0 in [PHASES.md](../PHASES.md), which recommends making it private. You can host Pages from a private repo on a paid plan, or publish these two files to a separate public repo.

## Keeping them true

These documents make specific factual claims about the app's behaviour. If any of the following changes, the privacy policy must change with it:

- audio ever being uploaded, or `requiresOnDeviceRecognition` being relaxed
- new data sent to Groq or any other third party
- new fields collected in the profile
- analytics or crash reporting being added
