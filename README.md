# Spasht: Real-Time Speech Therapy Engine

An iOS application designed to provide immediate feedback for individuals with stuttering disfluencies. Spasht listens, aligns text to audio in real-time, and generates actionable fluency metrics. No cloud processing delays, no privacy concerns—just raw, on-device machine learning.

![Swift](https://img.shields.io/badge/Swift-5.x-FA7343?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16.0+-000000?style=flat&logo=apple&logoColor=white)
![CoreML](https://img.shields.io/badge/CoreML-On--Device-007AFF?style=flat)

---

## The Tech Behind the Talk

- **Real-Time Disfluency Detection:** Built a speech analysis system that actively detects repetitions, prolongations, and blocks using timestamped speech recognition.
- **Dynamic Time Warping (DTW):** Engineered a text-audio alignment pipeline that compares the user's spoken audio directly against reference prompts to pinpoint exact moments of disfluency.
- **Closed-Loop Feedback Engine:** Automatically identifies "trouble words" from the user's speech patterns and dynamically spawns personalized practice tasks. It learns what you struggle with and drills it.
- **Actionable Analytics:** Computes and visualizes core fluency metrics—accuracy, block rate, and overall speech continuity—giving users concrete insight into their progress.
- **Zero-Latency Inference:** Fully optimized for on-device processing. This guarantees both privacy (audio never leaves the device) and the millisecond-level latency necessary for legitimate real-time feedback.

---

## Architecture Overview

- **Audio Pipeline:** `SFSpeechRecognizer` coupled with custom `AVAudioEngine` tapping to extract raw PCM buffers.
- **Alignment Engine:** Custom Swift implementation of the DTW algorithm running on background GCD queues to avoid main-thread blocking.
- **Data Persistence:** CoreData handles the storage of longitudinal fluency metrics and trouble-word histories.

---

## Getting Started

### Prerequisites
- Xcode 14.0 or newer
- An iOS device running iOS 16.0+ (Simulator microphone support is notoriously finicky for audio analysis, highly recommend testing on physical hardware).

### Installation
1. Clone the repository:
   ```bash
   git clone https://github.com/amayIIp/MITWPU_Group_16.git
   ```
2. Open the `.xcodeproj` (or `.xcworkspace` if using CocoaPods/SPM) in Xcode.
3. Select your physical iOS device.
4. Hit `Cmd + R` to build, deploy, and start talking.

---

## License

This project is for educational and clinical research purposes. 
