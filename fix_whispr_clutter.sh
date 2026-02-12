#!/bin/bash

echo "🚿 Cleaning up Whispr ghost processes..."
killall Whispr 2>/dev/null

echo "🔐 Resetting Microphone permissions for com.nexys.Whispr..."
# This forces macOS to forget the previous 'denied' or 'missing' state
tccutil reset Microphone com.nexys.Whispr 2>/dev/null
tccutil reset Accessibility com.nexys.Whispr 2>/dev/null

echo "🧹 Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/Whispr-*

echo "✅ Done! Please Re-build and Run in Xcode."
echo "💡 When the app starts, press the hotkey. It should now prompt for MIC access properly."
