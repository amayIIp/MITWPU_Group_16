

# Spasht: Real-Time Speech Therapy App
<p align="center">

<img  src="https://github.com/user-attachments/assets/cef2abff-da21-4821-b782-4900c5a155ea" width="120"/>
<img src="https://github.com/user-attachments/assets/2701d49f-8325-401e-b89d-58255aa77dd9" width="120"/>
<img src="https://github.com/user-attachments/assets/74304498-e948-4f73-a15b-08761795f55e" width="120"/>
<img  src="https://github.com/user-attachments/assets/6fcc67ec-d159-402c-afd4-24f9ca4fb4ac" width="120"/>
<img  src="https://github.com/user-attachments/assets/68c85f4e-4632-432e-b192-629edf961c28" width="120"/>
<img src="https://github.com/user-attachments/assets/3dfe3a95-6b7d-49ec-9832-caaed14b7a48" width="120"/>
<img  src="https://github.com/user-attachments/assets/6bbe3a39-9df4-49be-958f-f4942289fb6d" width="120"/>
<img  src="https://github.com/user-attachments/assets/d922c119-9170-4128-b612-7df3bc98bfec" width="120"/>
<img  src="https://github.com/user-attachments/assets/4d7da62e-34d8-4250-9f63-9c03e114d6c3" width="120"/>
<img src="https://github.com/user-attachments/assets/477e3992-79b8-4866-8abc-e673f43abd6e" width="120"/>




  <img src="https://github.com/user-attachments/assets/165bf6aa-1042-4a04-a6e1-5e36c64cf9ed" width="120"/>
  <img src="https://github.com/user-attachments/assets/39995724-5da4-4994-b3ea-521396bc0ef7" width="120"/>
   <img src="https://github.com/user-attachments/assets/881a5b2b-a862-4199-a326-41a5175f5c3d" width="120"/>
  <img src="https://github.com/user-attachments/assets/9b9d79ae-afd6-4578-953a-614b20fa750b" width="120"/>
   <img src="https://github.com/user-attachments/assets/905cc7ec-9627-4a79-9923-a114115e88e6" width="120"/>
   <img src="https://github.com/user-attachments/assets/c5f7d8e0-a5c8-45d5-b3f2-825de4927c21" width="120"/>
 <img src="https://github.com/user-attachments/assets/10b5f180-5947-4207-85ad-eb9b34848306" width="120"/>
  
 
  
  <img src="https://github.com/user-attachments/assets/73fceb13-739a-4b10-b8b8-5ab87ccffeeb" width="120"/>
  
</p>





# Spasht — Real-Time Speech Therapy App

> An iOS app that delivers immediate, on-device feedback to people with stuttering disfluencies. Spasht listens to your speech, aligns it to reference text in real time using Dynamic Time Warping, and gives you detailed fluency metrics — all without a single byte leaving your phone.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Module Breakdown](#module-breakdown)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Data & Privacy](#data--privacy)
- [Team](#team)
- [License](#license)

---

## Overview

Spasht (meaning *clear* or *articulate* in Sanskrit) is a clinically-inspired speech therapy companion built for people who stutter. The app guides users through a structured daily routine of warm-up exercises, reading sessions, and open-ended conversations, then uses a custom stutter-analysis pipeline to surface exactly which words are causing difficulty and why.

Everything runs on-device using Apple's `SFSpeechRecognizer`, `AVAudioEngine`, and a WhisperKit fallback, so there is no cloud processing latency and no privacy trade-off.

---

## Key Features

### 🎤 Real-Time Stutter Detection
- Captures raw PCM audio via a live `AVAudioEngine` tap.
- Runs speech recognition on-device using `SFSpeechRecognizer` with `requiresOnDeviceRecognition = true`.
- A WhisperKit model is invoked as a higher-accuracy fallback when a session ends.
- A custom `StutterAnalyzer` compares the recognized transcript against the reference text using Dynamic Time Warping (DTW) to pinpoint repetitions, prolongations, and blocks with timestamp-level precision.

### 📊 Fluency Analytics
- Each reading session produces a `StutterJSONReport` containing:
  - **Fluency Score** (0–100)
  - Per-category breakdown: repetitions, prolongations, blocks, correct words
  - **Troubled Words** list with disfluency type and first-letter analysis
  - **Longest smooth paragraph** streak
- Conversation sessions track filler-word percentage and longest uninterrupted speech run.
- A bar waveform view running at 60 fps via `CADisplayLink` gives instant visual feedback during recording.

### 📅 Daily Task System
- Five personalized daily tasks are generated each session.
- A radial progress chart and three colour-coded progress bars (Exercises / Reading / Conversation) visualize goal completion.
- Daily streaks are tracked and displayed with an animated flame badge.

### 🧩 Exercises & Warm-Ups
- A **Library** of structured speech exercises with instruction screens and a results summary.
- **Fun Exercises**: Story Cubes (creative spoken storytelling) and a Video Diary feature.
- Exercises are categorised by source (`exercises`, `warmup`, `dailyTasks`) and duration.

### 📖 Guided Reading Sessions
- Paragraph-by-paragraph reading prompts with smooth scroll alignment.
- Real-time waveform feedback during recording.
- Post-session analysis drives the per-letter stutter heatmap.

### 💬 Open Conversation Mode
- Free-form voice recording via `VoiceViewController`.
- Filler-word detection and longest-smooth-talk metrics are stored per session.

### 🏆 Awards & Gamification
- An `AwardsManager` tracks progress across multiple achievement categories.
- Weekly challenges unlock new badge tiers.
- The most recently achieved award is featured on the Home screen.

### ☁️ Optional Cloud Sync (Supabase)
- Account mode enables full bidirectional sync via Supabase.
- A delta-sync mechanism (`hasPendingCloudChanges`) avoids unnecessary full pulls.
- Guest mode keeps all data 100% local with zero network calls.
- A strict `guardAccountMode()` guard prevents accidental writes in guest mode.

### 🧪 Onboarding & Baseline Assessment
- An animated onboarding flow collects user name, phoneme preferences, and records a baseline reading session.
- The `StutterAnalyzer` generates an initial report that seeds the user's personal profile.

---

## Architecture

```
Spasht/
├── AppDelegate.swift
├── SceneDelegate.swift
├── Onboarding/          # User registration, login, and baseline speech test
├── HomePage/            # Dashboard: streaks, daily tasks, progress bars, awards
├── Exercises/           # Structured exercises, warm-ups, fun exercises (Story Cubes, Video Diary)
├── Reading/             # Guided paragraph reading with real-time waveform
├── Conversation/        # Free-form voice session recording and analysis
├── Summary/             # Post-session analytics report
├── Awards/              # Achievement system and badge gallery
├── Profile/             # User profile management
└── Networking/          # Supabase client, session manager, bidirectional sync engine
```

The app follows an **MVC pattern** with each module containing `Controller/`, `Model/`, and `View/` subdirectories. Shared managers (`LogManager`, `DatabaseManager`, `AwardsManager`, `SessionManager`, `SupabaseSyncManager`) are singletons accessed across modules.

---

## Module Breakdown

| Module | Key Files | Responsibility |
|---|---|---|
| **Onboarding** | `TestViewController`, `LastOnboardingViewController`, `LoginViewController`, `SignUpViewController` | Baseline speech test, DTW analysis, account creation |
| **Home** | `HomePageViewController`, `PracticeViewController`, `DailyTasksViewController` | Dashboard, streak display, daily goal tracking |
| **Exercises** | `ExerciseTemplateViewController`, `ExerciseTabViewController`, `LibraryViewController` | Exercise playback, instruction screens, results |
| **Fun Exercises** | `StoryCubesViewController`, `VideoDiaryViewController` | Creative spoken exercises |
| **Reading** | `ReadingViewController` (in `Controller/`) | Paragraph reading with waveform and scoring |
| **Conversation** | `VoiceViewController` | Free-form recording with filler-word analysis |
| **Summary** | `SummaryViewController` | Session-end analytics report |
| **Awards** | `AwardMainViewController`, `AwardsBaseViewController` | Achievement gallery, weekly challenges |
| **Profile** | Profile screens | User info, goals, account settings |
| **Networking** | `SupabaseSyncManager`, `SessionManager`, `SupabaseManager` | Delta cloud sync, auth guard, Supabase client |

---

## Tech Stack

| Layer | Technology |
|---|---|
| **Language** | Swift 5.9+ |
| **UI Framework** | UIKit (Storyboard + programmatic views) |
| **Speech Recognition** | `SFSpeechRecognizer` (Apple, on-device) |
| **Audio Engine** | `AVAudioEngine` + `AVAudioFile` |
| **ML / Transcription** | WhisperKit (on-device Whisper model fallback) |
| **Alignment Algorithm** | Custom Swift DTW implementation |
| **Local Database** | SQLite3 (via direct C API) |
| **Cloud Backend** | Supabase (Auth + Postgres) |
| **Minimum iOS** | iOS 16.0 |
| **Xcode** | 14.0 or newer |

---

## Getting Started

### Prerequisites

- **Xcode 14.0+** installed on macOS
- A **physical iPhone** running **iOS 16.0 or later**
  > ⚠️ A real device is strongly recommended. The iOS Simulator's microphone pipeline is unreliable for live audio analysis.

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/amayIIp/MITWPU_Group_16.git
   cd MITWPU_Group_16
   ```

2. **Open in Xcode**
   ```bash
   open "Stuttering App.xcodeproj"
   ```

3. **Configure signing**
   - Select the project in the navigator.
   - Under *Signing & Capabilities*, set your Apple Developer Team.

4. **Connect your iPhone** and select it as the run destination.

5. **Build & Run**
   ```
   Cmd + R
   ```

6. **Grant permissions** when prompted:
   - Microphone access (required for all recording features)
   - Speech Recognition access (required for on-device transcription)

### First Launch

On first launch, you will be taken through the onboarding flow:
1. Enter your name and select the phoneme sounds you find most challenging.
2. Complete a baseline reading test (three paragraphs).
3. The app analyses your speech and generates your initial fluency profile.
4. You can optionally create an account to enable cloud sync across devices.

---

## Data & Privacy

| Concern | How Spasht Handles It |
|---|---|
| Audio storage | Audio is written to a **temporary file** during a session and processed locally. It is never uploaded. |
| Speech recognition | Uses `requiresOnDeviceRecognition = true` — no audio leaves the device for transcription. |
| Analytics | All session data is stored in a local **SQLite database** on the device. |
| Cloud sync | Only **structured analytics** (scores, word lists, counts) are synced to Supabase — never raw audio. Cloud sync is **opt-in** and requires account creation. |
| Guest mode | In guest mode, the `guardAccountMode()` guard blocks every Supabase write call, ensuring zero network traffic. |

---

## Team

Built by **MIT-WPU Group 16** as part of a project submission.

| Name | Role |
|---|---|
| Prathamesh Patil | iOS Development, Audio Pipeline, DTW Engine |
| *(Add other members)* | *(Add roles)* |

---

## License

This project is intended for **educational and clinical research purposes only**.  
Not cleared for medical or diagnostic use. All analysis is indicative only.
