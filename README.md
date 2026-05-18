# Spasht: Real-Time Speech Therapy App

<p align="center">
  <img src="https://github.com/user-attachments/assets/cef2abff-da21-4821-b782-4900c5a155ea" width="120"/>
  <img src="https://github.com/user-attachments/assets/2701d49f-8325-401e-b89d-58255aa77dd9" width="120"/>
  <img src="https://github.com/user-attachments/assets/74304498-e948-4f73-a15b-08761795f55e" width="120"/>
  <img src="https://github.com/user-attachments/assets/6fcc67ec-d159-402c-afd4-24f9ca4fb4ac" width="120"/>
  <img src="https://github.com/user-attachments/assets/68c85f4e-4632-432e-b192-629edf961c28" width="120"/>
</p>

# Spasht — Real-Time Speech Therapy App

> An iOS app that helps people who stutter practice speech independently, receive fluency feedback, and track improvement over time.

---

## Table of Contents

- [Overview](#overview)
- [Key Features](#key-features)
- [Architecture](#architecture)
- [Module Breakdown](#module-breakdown)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [WhisperKit Model Setup](#whisperkit-model-setup)
- [Data & Privacy](#data--privacy)
- [Team](#team)
- [License](#license)

---

## Overview

Spasht, meaning *clear* or *articulate* in Sanskrit, is a clinically-inspired iOS speech practice app built for people who stutter.

Many people who stutter find it difficult to practice alone because they do not get instant feedback. Spasht solves this by providing guided speech exercises, AI-generated reading practice, open-ended conversation mode, and detailed fluency analytics.

The app records the user's speech, transcribes it, compares it with the expected text, and detects possible repetitions, prolongations, and blocks. It then gives a fluency score, troubled words, and progress insights.

---

## Key Features

### Real-Time Stutter Detection

- Captures speech using `AVAudioEngine`.
- Uses Apple `SFSpeechRecognizer` for speech recognition.
- Uses WhisperKit as a higher-accuracy fallback transcription model.
- Compares the user's transcript with the reference text.
- Detects:
  - repetitions
  - prolongations
  - blocks
  - troubled words
  - difficult starting letters

### Fluency Analytics

Each reading session produces a `StutterJSONReport` containing:

- fluency score from 0 to 100
- repetition percentage
- prolongation percentage
- block percentage
- correct speech percentage
- troubled words
- first-letter analysis
- session duration

### Daily Task System

- Generates five daily practice tasks.
- Tracks daily completion.
- Maintains streaks.
- Shows progress for:
  - exercises
  - reading
  - conversation

### Exercises & Warm-Ups

Includes structured fluency exercises such as:

- Airflow Practice
- Gentle Onset
- Flexible Pacing
- Light Contacts
- Prolongation
- Preparatory Set
- Pull-Out
- Block Correction

Also includes fun exercises like:

- Story Cubes
- Video Diary
- Tongue Twisters
- Mirror Routine

### Guided Reading Mode

- Generates AI paragraphs based on selected topics.
- Can include words starting with the user's difficult phonemes.
- Highlights text while the user reads.
- Records audio and gives post-session fluency feedback.
- Uses the stuttering detection algorithm to generate a detailed report.

### Conversation Mode

- Lets users speak with an AI conversation partner.
- Uses speech-to-text for user input.
- Uses text-to-speech for AI replies.
- Keeps responses short and supportive.
- Helps users practice spontaneous speaking.

### Awards & Gamification

- Tracks achievements.
- Supports weekly challenges.
- Rewards consistency.
- Encourages users to keep practicing regularly.

### Optional Cloud Sync

- Guest mode stores everything locally.
- Account mode enables Supabase sync.
- Syncs structured analytics only.
- Raw audio is not uploaded.

---

## Architecture

```text
Spasht/
├── AppDelegate.swift
├── SceneDelegate.swift
├── Onboarding/
├── HomePage/
├── Exercises/
├── Reading/
├── Conversation/
├── Summary/
├── Awards/
├── Profile/
└── Networking/
```

The app follows an MVC-style structure.

Each major feature is divided into:

- `Controller`
- `Model`
- `View`

Shared managers are used across the app:

- `LogManager`
- `DatabaseManager`
- `AwardsManager`
- `SessionManager`
- `SupabaseSyncManager`
- `GeminiService`
- `WhisperDetectionManager`

---

## Module Breakdown

| Module | Key Files | Responsibility |
|---|---|---|
| Onboarding | `TestViewController`, `LoginViewController`, `SignUpViewController` | Baseline test, login, signup |
| Home | `HomePageViewController`, `DailyTasksViewController` | Dashboard, streaks, daily goals |
| Exercises | `ExerciseTemplateViewController`, `LibraryViewController` | Guided fluency exercises |
| Reading | `DetailViewController`, `ReadingResultViewController`, `StutterAnalyzer` | Reading practice and fluency scoring |
| Conversation | `VoiceViewController`, `VoiceViewModel` | AI voice conversation |
| Awards | `AwardsManager`, `AwardsEvaluator` | Achievement tracking |
| Profile | Profile controllers | User details and goals |
| Networking | `SupabaseSyncManager`, `SessionManager`, `SupabaseManager` | Auth and cloud sync |

---

## Stuttering Detection Algorithm

The core stuttering detection logic is implemented in `StutterAnalyzer.swift`.

The pipeline works as follows:

1. The app records the user's speech.
2. Speech is converted into text using Apple Speech Recognition or WhisperKit.
3. The reference paragraph and transcript are normalized.
4. The app aligns both word sequences using dynamic programming.
5. It classifies differences as:
   - repetition
   - prolongation
   - block
6. It calculates a weighted fluency score.
7. It returns a structured JSON report.

### Repetition Detection

If the user repeats the same word immediately, it is marked as a repetition.

Example:

```text
Reference: I want to go
Spoken:    I I want to go
```

Detected repetition:

```text
I
```

### Prolongation Detection

If the spoken word does not match the expected word, or an extra non-repeated word appears, it is treated as a prolongation-like disfluency.

### Block Detection

Blocks are detected using word timing.

The app calculates:

```text
duration per character = word duration / number of characters
```

Then it compares each word with the user's average speaking pace.

A word is marked as a block if it takes significantly longer than the user's average duration-per-character.

This avoids false positives for long words.

### Fluency Score

The app applies weighted penalties:

```text
repetition   = 1.0
prolongation = 1.5
block        = 2.0
```

Formula:

```text
fluencyScore = 100 - ((weightedPenalty / totalReferenceWords) * 100)
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift |
| UI Framework | UIKit, Storyboards |
| Audio | AVAudioEngine, AVAudioSession, AVAudioFile |
| Speech Recognition | SFSpeechRecognizer |
| Transcription Fallback | WhisperKit |
| AI Generation | Apple Foundation Models / Gemini fallback |
| Text-to-Speech | AVSpeechSynthesizer |
| Local Database | SQLite3 |
| Cloud Backend | Supabase Auth + Postgres |
| Authentication | Supabase, Google Sign-In |
| Platform | iOS |
| IDE | Xcode |

---

## Getting Started

### Prerequisites

- macOS
- Xcode 14 or later
- iPhone running iOS 16 or later
- Internet connection for first-time model download
- Python 3 recommended for model setup

A physical iPhone is recommended because the iOS simulator microphone pipeline can be unreliable for live speech analysis.

---

## Installation

### 1. Clone the repository

```bash
git clone https://github.com/amayIIp/MITWPU_Group_16.git
cd MITWPU_Group_16
```

### 2. Set up the WhisperKit model

If the folder below already exists, you can skip this step:

```text
Stuttering App/openai_whisper-small.en
```

If it does not exist, follow the model setup section below.

### 3. Open the project in Xcode

```bash
open "Stuttering App.xcodeproj"
```

### 4. Configure signing

In Xcode:

1. Select the project.
2. Go to **Signing & Capabilities**.
3. Select your Apple Developer Team.
4. Connect your iPhone.
5. Choose your iPhone as the run destination.

### 5. Build and run

Press:

```text
Cmd + R
```

### 6. Grant permissions

When prompted, allow:

- Microphone access
- Speech Recognition access

---

## WhisperKit Model Setup

Spasht uses the WhisperKit model folder:

```text
openai_whisper-small.en
```

The app expects the model at:

```text
Stuttering App/openai_whisper-small.en
```

This model is used for offline transcription fallback.

---

### Option 1: If You Have Python Installed

Run this from the repository root:

```bash
python3 setup_model.py
```

If your system uses `python` instead of `python3`, run:

```bash
python setup_model.py
```

The script will:

- check if `huggingface_hub` is installed
- install it automatically if missing
- download the WhisperKit model
- copy it into the Xcode project folder

---

### Option 2: If You Do Not Have Python Installed

Run:

```bash
bash setup_model.sh
```

This script will:

- check whether Python 3 is available
- install Python 3 using Homebrew if missing
- run `setup_model.py`
- download the WhisperKit model automatically

This may take a few minutes because the model is several hundred MB.

---

### Xcode Model Check

After downloading, make sure this folder is visible in Xcode:

```text
openai_whisper-small.en
```

It should be added as a folder reference to the app target.

If the app cannot find the model, remove and re-add the folder in Xcode:

1. Right-click the project.
2. Choose **Add Files to "Stuttering App"**.
3. Select `openai_whisper-small.en`.
4. Enable **Copy items if needed**.
5. Select the app target.
6. Add it as a folder reference.

---

## First Launch

On first launch:

1. Enter your name.
2. Select phonemes or sounds you find difficult.
3. Complete a baseline reading test.
4. The app generates your initial fluency profile.
5. You can continue as guest or create an account.

---

## Data & Privacy

| Concern | How Spasht Handles It |
|---|---|
| Audio storage | Audio is stored temporarily during a session and processed locally. |
| Speech recognition | Uses Apple Speech Recognition and WhisperKit for transcription. |
| Local analytics | Session data is stored in SQLite on the device. |
| Cloud sync | Only structured analytics are synced to Supabase. |
| Raw audio | Raw audio is not uploaded. |
| Guest mode | Guest users remain local-only. |
| Account mode | Supabase sync is enabled only after login/signup. |

---

## Limitations

- The app is not a medical diagnostic tool.
- Detection accuracy depends on transcription quality.
- Background noise can affect speech recognition.
- The stuttering detection algorithm is indicative and should be clinically validated before medical use.

---

## Team

Built by **MIT-WPU Group 16** as part of a project submission.

| Team Members |
|---|
| Naitik Rathore |
| Prathamesh Patil |
| Amay Puthiyedath |
| Krish Jain |

---

## License

This project is intended for educational and clinical research purposes only.

Not cleared for medical or diagnostic use. All analysis is indicative only.
