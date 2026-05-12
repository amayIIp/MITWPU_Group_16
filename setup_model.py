#!/usr/bin/env python3
"""
setup_model.py — Download the bundled WhisperKit model (openai_whisper-small.en)
into the Xcode project so Spasht can run offline without a loading screen.

Run once from the repo root:
    python3 setup_model.py

No manual pip installs needed — this script handles everything automatically.
"""

import os
import sys
import shutil
import subprocess


REPO_ROOT = os.path.dirname(os.path.abspath(__file__))
DEST = os.path.join(REPO_ROOT, "Stuttering App", "openai_whisper-small.en")
TMP_DIR = "/tmp/whisperkit-small-en-setup"


# ── Step 1: Ensure huggingface_hub is available ──────────────────────────────

def ensure_huggingface_hub():
    try:
        import huggingface_hub  # noqa: F401
        print("✅ huggingface_hub is already installed.")
    except ImportError:
        print("📦 huggingface_hub not found — installing it now...")
        # Try pip, then pip3 as a fallback
        pip_cmd = None
        for candidate in ["pip3", "pip"]:
            result = subprocess.run(
                [candidate, "--version"],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL
            )
            if result.returncode == 0:
                pip_cmd = candidate
                break

        if pip_cmd is None:
            print("\n❌ pip is not installed on this machine.")
            print("   Please install pip first, then re-run this script:")
            print("   https://pip.pypa.io/en/stable/installation/\n")
            sys.exit(1)

        install_result = subprocess.run(
            [pip_cmd, "install", "huggingface_hub"],
            check=False
        )
        if install_result.returncode != 0:
            print("\n❌ Failed to install huggingface_hub automatically.")
            print(f"   Please run manually:  {pip_cmd} install huggingface_hub\n")
            sys.exit(1)

        print("✅ huggingface_hub installed successfully.\n")


# ── Step 2: Download the model ───────────────────────────────────────────────

def download_model():
    from huggingface_hub import snapshot_download

    print("📥 Downloading openai_whisper-small.en (~464 MB) from HuggingFace...")
    print("   This is a one-time setup step — grab a coffee ☕\n")

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
        print("   The download may have failed. Try running the script again.\n")
        sys.exit(1)

    print(f"\n📂 Copying model into Xcode project...")
    shutil.copytree(src, DEST)
    print(f"✅ Done! Model is at:\n   {DEST}")
    print("\n🔨 Now open Xcode and build the app — no loading screen during onboarding!")


# ── Entry point ───────────────────────────────────────────────────────────────

def main():
    # Already downloaded — nothing to do
    if os.path.isdir(DEST):
        print(f"✅ Model already present at:\n   {DEST}")
        print("   Nothing to do — open Xcode and build!")
        return

    ensure_huggingface_hub()
    download_model()


if __name__ == "__main__":
    main()
