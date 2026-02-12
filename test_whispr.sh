#!/bin/bash

# Whispr End-to-End Test Script
# This script tests the entire Whispr pipeline manually

set -e

echo "🧪 Whispr Pipeline Test"
echo "======================="
echo ""

# Check whisper.cpp binary
echo "1️⃣  Checking whisper.cpp binary..."
WHISPER_BIN="/Users/mrkkonecny/whispr/whisper.cpp/build/bin/whisper-cli"
if [ -f "$WHISPER_BIN" ]; then
    echo "   ✅ Found whisper-cli"
else
    echo "   ❌ whisper-cli NOT FOUND at $WHISPER_BIN"
    exit 1
fi

# Check model
echo "2️⃣  Checking Whisper model..."
MODEL_PATH="/Users/mrkkonecny/whispr/whisper.cpp/models/ggml-medium.bin"
if [ -f "$MODEL_PATH" ]; then
    MODEL_SIZE=$(du -h "$MODEL_PATH" | cut -f1)
    echo "   ✅ Found model ($MODEL_SIZE)"
else
    echo "   ❌ Model NOT FOUND at $MODEL_PATH"
    exit 1
fi

# Test with sample audio (if available)
echo "3️⃣  Looking for test audio files..."
TEST_AUDIO="/Users/mrkkonecny/whispr/whisper.cpp/samples/jfk.wav"
if [ -f "$TEST_AUDIO" ]; then
    echo "   ✅ Found test audio: $TEST_AUDIO"
    echo ""
    echo "4️⃣  Running test transcription..."
    echo "   (This will take a few seconds)"
    echo ""
    
    "$WHISPER_BIN" -m "$MODEL_PATH" -f "$TEST_AUDIO" -nt -t 4 -l auto
    
    echo ""
    echo "✅ Test complete! If you saw transcription above, whisper.cpp is working!"
else
    echo "   ⚠️  No test audio found, skipping transcription test"
    echo "   ℹ️  To test manually:"
    echo "      1. Record a short audio file (WAV format)"
    echo "      2. Run: $WHISPER_BIN -m $MODEL_PATH -f YOUR_AUDIO.wav -nt"
fi

echo ""
echo "5️⃣  Checking Xcode project..."
XCODE_PROJECT="/Users/mrkkonecny/whispr/Whispr/Whispr.xcodeproj"
if [ -d "$XCODE_PROJECT" ]; then
    echo "   ✅ Xcode project found"
else
    echo "   ❌ Xcode project NOT FOUND"
    exit 1
fi

echo ""
echo "✅ All checks passed!"
echo ""
echo "📝 Next steps:"
echo "   1. Open Xcode: open '$XCODE_PROJECT'"
echo "   2. Build: Cmd+B"
echo "   3. Run: Cmd+R"
echo "   4. Test: Cmd+Shift+Space (twice - start/stop recording)"
echo ""
