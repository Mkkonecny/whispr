#!/bin/bash
#
# Whispr - Permission Helper
# Helps grant microphone and accessibility permissions
#

echo "🎤 Whispr Permission Helper"
echo "============================="
echo ""

# Check Accessibility
if ! command -v osascript &> /dev/null; then
    echo "❌ Cannot check permissions"
    exit 1
fi

# Check if app is running
APP_PID=$(pgrep -x "Whispr" || echo "")

if [ -z "$APP_PID" ]; then
    echo "ℹ️  Whispr is not currently running"
    echo ""
    echo "To grant microphone permission:"
    echo "1. Run Whispr from Xcode (Cmd+R)"
    echo "2. System should prompt for microphone access"
    echo "3. Click 'OK' to allow"
    echo ""
    echo "If no prompt appears:"
    echo "4. Open System Settings"
    echo "5. Privacy & Security → Microphone"
    echo "6. Click '+' button"
    echo "7. Navigate to Applications and add Whispr"
    exit 0
fi

echo "✅ Whispr is running (PID: $APP_PID)"
echo ""

# Instructions
echo "📝 Manual Permission Grant:"
echo ""
echo "1. Open System Settings (⚙️)"
echo "2. Go to: Privacy & Security → Microphone"
echo "3. Look for 'Whispr' in the list"
echo ""
echo "If Whispr is NOT in the list:"
echo "4. Click the '+' button at the bottom"
echo "5. Navigate to your Applications folder"
echo "6. Select Whispr.app"
echo "7. Toggle it ON"
echo ""
echo "Then stop the app (in Xcode) and run again (Cmd+R)"
echo ""

# Open System Settings to the right place
echo "Press ENTER to open System Settings to Microphone permissions..."
read

open "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"

echo ""
echo "✅ System Settings opened!"
echo "   Look for 'Whispr' in the list and toggle it ON."
