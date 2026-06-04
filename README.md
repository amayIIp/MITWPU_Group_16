# Spasht — Real-Time Speech Therapy App

> An iOS app that helps people who stutter practice speech independently, receive fluency feedback, and track improvement over time.

---

## 🌟 Key Features

### 🗣️ Real-Time Stutter Detection & Analytics
- Captures raw PCM audio via a live `AVAudioEngine` tap.
- Runs speech recognition on-device using Apple's `SFSpeechRecognizer` (`requiresOnDeviceRecognition = true`).
- A custom **StutterAnalyzer** uses Dynamic Time Warping (DTW) to pinpoint repetitions, prolongations, and blocks with timestamp-level precision.
- Generates post-session `StutterJSONReport` analytics containing fluency scores, per-letter heatmaps, and trouble-word tracking.
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

### 🤖 Interactive AI Conversational Partner
- Engage in free-form, open-ended spoken conversations with an AI specifically instructed to help you practice your speech.
- **Smart Fallback Architecture:** Uses on-device Foundation Models first. If unavailable, it seamlessly falls back to cloud-based **Llama 3 (via Groq API)** for ultra-low latency conversational responses.
- **Neural Text-to-Speech:** Leverages Apple's Premium and Enhanced neural TTS voices for incredibly natural, human-like voice responses with dynamic audio session management to prevent quality degradation.

### 🎧 Delayed Auditory Feedback (DAF)
- Real-time DAF support during reading exercises.
- Plays your voice back to you with a slight delay (customizable from 0.05s to 1.5s) to naturally help improve speech fluency and pacing. (Requires headphones).

### 📖 Guided & AI-Generated Reading Sessions
- Practice reading predefined categories (Science, Space, Mindset) or enter your own custom text.
- Integrated **AI Paragraph Generation** dynamically creates reading material based on the specific phonemes and letters you struggle with the most.

### 🏆 Gamification & Daily Goals
- Five personalized daily tasks generated based on your stuttering profile.
- A radial progress chart, daily streak flames, and an `AwardsManager` that tracks weekly challenges and unlocks achievement badges.
- Creative exercises like Story Cubes and Video Diaries.

---

## 🏗️ Architecture

Spasht is built on a clean **MVVM architecture**:

```text
Spasht/
├── Model/               # Core algorithms (DTW, StutterAnalyzer), Networking (GroqService, Supabase)
├── View/                # Storyboards, Custom Cells, UIKit Views
│   ├── Conversation/    # AI Voice Chat (VoiceViewController)
│   ├── Reading/         # Guided Reading & DAF (CategoriesViewController)
│   ├── Exercises/       # Speech Warmups
│   └── Profile/         # Analytics & User Data
└── ViewModel/           # Business logic binding (e.g., VoiceViewModel)
```

**Tech Stack:**
- **Language:** Swift 5.9+
- **UI:** UIKit (Storyboards & programmatic)
- **Speech/Audio:** `AVAudioEngine`, `SFSpeechRecognizer`, `AVSpeechSynthesizer`
- **AI/LLM:** Local Foundation Models, Groq API (Llama 3)
- **Database:** SQLite3 (local), Supabase (cloud sync)

---

## 🚀 Getting Started

### Prerequisites
- **Xcode 15.0+** installed on macOS
- A **physical iPhone** running **iOS 17.0 or later**
  > ⚠️ *A physical device is required. The iOS Simulator does not support the necessary microphone pipelines or neural TTS voices.*

### Installation
1. **Clone the repository**
   ```bash
   git clone https://github.com/amayIIp/MITWPU_Group_16.git
   cd MITWPU_Group_16
   ```
2. **Open the project**
   ```bash
   open "Stuttering App.xcodeproj"
   ```
3. **Configure API Keys & Signing**
   - In Xcode, go to *Signing & Capabilities* and set your Apple Developer Team.
   - If using the AI conversation fallback, ensure your Groq API key is set in `AppSecrets.swift`.
4. **Build & Run** on your connected iPhone (`Cmd + R`).

---

## 🔒 Data & Privacy

Spasht is built with a privacy-first mindset:
- **Zero Audio Uploads:** Raw audio is processed strictly on-device using `SFSpeechRecognizer`. Your voice never leaves your phone.
- **Local First:** All fluency analytics and heatmaps are stored locally in SQLite. 
- **Optional Cloud Sync:** Users can opt-in to sync their *scores* (not audio) to a secure Supabase backend to track progress across devices. Guest mode completely disables all network traffic.

---

## 👨‍💻 Team

Built by **MIT-WPU Group 16** for educational and clinical research purposes:
- Naitik Rathore
- Prathamesh Patil
- Amay Puthiyedath
- Krish Jain

---

## 📄 License
This project is intended for **educational purposes only**. Not cleared for medical or diagnostic use. All analysis is indicative only.
