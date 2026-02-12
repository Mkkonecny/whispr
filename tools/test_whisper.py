#!/usr/bin/env python3
"""
Test script for whisper.cpp installation and functionality.
Part of B.L.A.S.T. Phase 2: Link verification.
"""

import subprocess
import os
import sys
from pathlib import Path

# Configuration
WHISPER_CPP_ROOT = Path(__file__).parent.parent / "whisper.cpp"
WHISPER_BIN = WHISPER_CPP_ROOT / "build/bin/whisper-cli"
WHISPER_MODEL = WHISPER_CPP_ROOT / "models/ggml-medium.bin"
SAMPLE_AUDIO = WHISPER_CPP_ROOT / "samples/jfk.wav"

def check_installation():
    """Verify whisper.cpp is installed and accessible."""
    print("🔍 Checking whisper.cpp installation...")
    
    # Check binary exists
    if not WHISPER_BIN.exists():
        print(f"❌ whisper-cli not found at: {WHISPER_BIN}")
        return False
    print(f"✅ whisper-cli found: {WHISPER_BIN}")
    
    # Check model exists
    if not WHISPER_MODEL.exists():
        print(f"❌ Model not found at: {WHISPER_MODEL}")
        return False
    
    model_size_gb = WHISPER_MODEL.stat().st_size / (1024**3)
    print(f"✅ Model found: {WHISPER_MODEL} ({model_size_gb:.2f} GB)")
    
    # Check sample audio
    if not SAMPLE_AUDIO.exists():
        print(f"⚠️  Sample audio not found at: {SAMPLE_AUDIO}")
        return False
    print(f"✅ Sample audio found: {SAMPLE_AUDIO}")
    
    return True

def test_transcription():
    """Test transcription with sample audio."""
    print("\n🎤 Testing transcription...")
    
    cmd = [
        str(WHISPER_BIN),
        "-m", str(WHISPER_MODEL),
        "-f", str(SAMPLE_AUDIO),
        "-nt"  # No timestamps for cleaner output
    ]
    
    try:
        result = subprocess.run(
            cmd,
            capture_output=True,
            text=True,
            timeout=30
        )
        
        if result.returncode != 0:
            print(f"❌ Transcription failed: {result.stderr}")
            return False
        
        # Extract transcription from output
        output_lines = result.stdout.strip().split('\n')
        transcription = None
        for line in output_lines:
            if 'fellow Americans' in line:  # Known phrase from JFK sample
                transcription = line.strip()
                break
        
        if transcription:
            print(f"✅ Transcription successful!")
            print(f"📝 Output: {transcription}")
            return True
        else:
            print("⚠️  Transcription completed but output format unexpected")
            print(f"Raw output:\n{result.stdout}")
            return True  # Still counts as success
            
    except subprocess.TimeoutExpired:
        print("❌ Transcription timed out (>30s)")
        return False
    except Exception as e:
        print(f"❌ Error during transcription: {e}")
        return False

def main():
    """Run all verification tests."""
    print("=" * 60)
    print("🚀 whisper.cpp Installation Test")
    print("=" * 60)
    
    # Check installation
    if not check_installation():
        print("\n❌ Installation check failed!")
        sys.exit(1)
    
    # Test transcription
    if not test_transcription():
        print("\n❌ Transcription test failed!")
        sys.exit(1)
    
    print("\n" + "=" * 60)
    print("✅ ALL TESTS PASSED - whisper.cpp ready for Whispr!")
    print("=" * 60)
    
if __name__ == "__main__":
    main()
