

# Spasht: Real-Time Speech Therapy App
<p align="center">
  <img src="https://github.com/user-attachments/assets/165bf6aa-1042-4a04-a6e1-5e36c64cf9ed" width="120"/>
  <img src="https://github.com/user-attachments/assets/39995724-5da4-4994-b3ea-521396bc0ef7" width="120"/>
   <img src="https://github.com/user-attachments/assets/881a5b2b-a862-4199-a326-41a5175f5c3d" width="120"/>
  <img src="https://github.com/user-attachments/assets/9b9d79ae-afd6-4578-953a-614b20fa750b" width="120"/>
   <img src="https://github.com/user-attachments/assets/905cc7ec-9627-4a79-9923-a114115e88e6" width="120"/>
   <img src="https://github.com/user-attachments/assets/c5f7d8e0-a5c8-45d5-b3f2-825de4927c21" width="120"/>
 <img src="https://github.com/user-attachments/assets/10b5f180-5947-4207-85ad-eb9b34848306" width="120"/>
  
 
  
  <img src="https://github.com/user-attachments/assets/73fceb13-739a-4b10-b8b8-5ab87ccffeeb" width="120"/>
  
</p>





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
