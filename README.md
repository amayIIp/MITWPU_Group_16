# Spasht: Real-Time Speech Therapy App

An iOS app built to give immediate feedback to people with stuttering disfluencies. Spasht listens, aligns what you say to the text in real-time, and gives you fluency metrics. Everything runs locally on the device using CoreML, so there is no cloud delay and zero privacy concerns.

---

## How It Works

*   **Real-Time Detection:** The app listens for repetitions, prolongations, and blocks using timestamped speech recognition.
*   **Dynamic Time Warping (DTW):** It uses a custom DTW pipeline to compare your audio directly against reference prompts to find exact moments of disfluency.
*   **Closed-Loop Feedback:** It automatically figures out your "trouble words" from your speech patterns and creates custom practice tasks just for you.
*   **Analytics:** It tracks your accuracy, block rate, and overall speech continuity over time so you can actually see your progress.
*   **Zero-Latency Inference:** Fully optimized for on-device processing. The audio never leaves your phone, which keeps your data secure and makes the feedback instant.

## Architecture

*   **Audio Pipeline:** Uses SFSpeechRecognizer and a custom AVAudioEngine tap to extract raw PCM audio buffers.
*   **Alignment Engine:** A native Swift implementation of the DTW algorithm running on background queues to keep the main UI fluid.
*   **Data Storage:** CoreData manages all the historical fluency metrics and trouble word tracking.

---

## Getting Started

### Requirements
*   Xcode 14.0 or newer
*   An iOS device running iOS 16.0 or better. I highly recommend using a real iPhone since the Simulator microphone pipeline can be very unreliable for audio analysis.

### Installation
1. Clone the project locally:
   ```bash
   git clone https://github.com/amayIIp/MITWPU_Group_16.git
   ```
2. Open the Xcode project file.
3. Select your connected iPhone.
4. Press `Cmd + R` to build and run the app.

---

## License

This project is intended for educational and clinical research purposes only. 
