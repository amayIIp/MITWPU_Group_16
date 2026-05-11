#!/usr/bin/env python3
"""
setup_model.py — Download the bundled WhisperKit model (openai_whisper-small.en)
into the Xcode project so Spasht can run offline without a loading screen.

Run once from the repo root:
    python3 setup_model.py

Requirements: pip install huggingface_hub  (already installed on dev machines)
"""

import os
import sys
import shutil
import subprocess

REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(REPO_ROOT, "Stuttering App", "openai_whisper-small.en")
TMP_DIR = "/tmp/whisperkit-small-en-setup"

def main():
    if os.path.isdir(DEST):
        print(f"✅ Model already present at:\n   {DEST}")
        print("   Nothing to do. Build the app in Xcode.")
        return

    print("📦 Downloading openai_whisper-small.en (~464MB) from HuggingFace...")
    print("   This is a one-time setup step.\n")

    try:
        from huggingface_hub import snapshot_download
    except ImportError:
        print("❌ huggingface_hub is not installed. Run:\n   pip install huggingface_hub\n")
        sys.exit(1)

    os.makedirs(TMP_DIR, exist_ok=True)

    snapshot_download(
        repo_id="argmaxinc/whisperkit-coreml",
        allow_patterns="openai_whisper-small.en/*",
        local_dir=TMP_DIR,
        repo_type="model"
    )

    src = os.path.join(TMP_DIR, "openai_whisper-small.en")
    if not os.path.isdir(src):
        print(f"❌ Expected model folder not found at: {src}")
        sys.exit(1)

    print(f"\n📂 Copying model to Xcode project...")
    shutil.copytree(src, DEST)
    print(f"✅ Done! Model is at:\n   {DEST}")
    print("\n🔨 Now open Xcode and build the app — no loading screen during onboarding!")

if __name__ == "__main__":
    main()
