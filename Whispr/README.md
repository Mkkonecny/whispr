# Whispr - macOS Voice-to-Text App

## 🎯 Ready to Build and Run!

All files are in place. This Xcode project is ready to build.

---

## 📁 Project Structure

```
Whispr/
├── Whispr.xcodeproj/          # ← Open this in Xcode
└── Whispr/                    # ← Source code
    ├── WhisprApp.swift        # Main app entry point
    ├── Info.plist             # Permissions configuration
    ├── Assets.xcassets/       # App icons
    ├── Managers/              # Core functionality
    │   ├── AudioCaptureManager.swift   # Mic capture + audio level metering
    │   ├── TranscriptionManager.swift  # whisper.cpp integration
    │   ├── TextInjectionManager.swift  # Paste into active app
    │   ├── HotkeyManager.swift         # Global shortcut handling
    │   ├── PreferencesManager.swift    # Persisted user settings
    │   └── ErrorManager.swift          # Error handling & recovery
    └── Views/
        ├── PreferencesView.swift       # Settings window
        ├── RecordingWindow.swift       # Floating recording bar (Dock-aware)
        └── RecordingBarView.swift      # Animated recording indicator
```

---

## 🚀 How to Build & Run

### Option 1: In Xcode (Recommended)
1. **Open:** Double-click `Whispr.xcodeproj`
2. **Build:** Press `Cmd + B`
3. **Run:** Press `Cmd + R`
4. **Grant permissions** when prompted
5. **Test:** Press & hold `Cmd+Shift+Space`, speak, release!

### Option 2: From Terminal
```bash
cd /Users/mrkkonecny/whispr/Whispr
open Whispr.xcodeproj
```

---

## ⚙️ Configuration (Already Done)

✅ **Info.plist** configured with:
- Microphone permission description
- Accessibility permission description
- Menu bar app (no Dock icon)

✅ **All managers** implement their SOPs:
- `audio_capture_sop.md`
- `whisper_transcription_sop.md`
- `text_injection_sop.md`
- `hotkey_management_sop.md`
- `error_handling_sop.md`

✅ **Dependencies:** All built-in frameworks (no external packages needed)

---

## 🎤 Usage

1. **Launch the app** (Cmd+R in Xcode)
2. **Look for mic icon** in menu bar (top-right)
3. **Open any text field** (TextEdit, Notes, Slack, etc.)
4. **Press & HOLD** `Cmd+Shift+Space`
5. **Speak** your message
6. **Release** the hotkey
7. **Watch** text appear instantly!

---

## 🔑 Permissions Required

### Microphone
- **Why:** To record your voice
- **Grant:** System will prompt on first use

### Accessibility
- **Why:** For global hotkey and text injection
- **Grant:** System Settings → Privacy & Security → Accessibility → Enable Whispr

---

## 🧪 Testing the Pipeline

### Manual Test
1. Open Terminal
2. Test whisper.cpp directly:
   ```bash
   cd /Users/mrkkonecny/whispr
   python3 tools/test_whisper.py
   ```

### In Xcode
1. Run the app (Cmd+R)
2. Check Console for debug logs
3. Watch for:
   - `🎤 Recording started`
   - `🔄 Starting transcription`
   - `✅ Transcription complete`
   - `💉 Injecting text`

---

## 📊 Tech Stack

- **Language:** Swift 5.9+
- **UI:** SwiftUI
- **Audio:** AVFoundation
- **Transcription:** whisper.cpp (local, Metal-accelerated)
- **Platform:** macOS 13.0+
- **Hardware:** Optimized for Apple Silicon (M1/M2/M3)

---

## 🎯 Features

- ✅ **100% Local Processing** - No cloud, complete privacy
- ✅ **99 Languages** - Auto-detected
- ✅ **Metal Acceleration** - Fast transcription on M-series chips
- ✅ **System-Wide** - Works in any macOS app
- ✅ **Menu Bar App** - Non-intrusive, always available
- ✅ **Global Hotkey** - Cmd+Shift+Space (hold to record)
- ✅ **Floating Recording Bar** - Animated, Dock-aware indicator above the Dock
- ✅ **Model Selection** - Choose between Base (fast) and Medium (accurate) models
- ✅ **Polish Mode** - AI-powered text cleanup for filler words & formatting
- ✅ **Audio Level Visualization** - Real-time mic level during recording
- ✅ **60-Second Recordings** - Configurable limit
- ✅ **Smart Error Handling** - Self-annealing recovery

---

## ⏭️ Next Steps

Future enhancements:
- [ ] Custom hotkey recorder
- [ ] Usage statistics
- [ ] Auto-update mechanism
- [ ] Additional whisper.cpp model sizes (tiny, small, large)

---

## 🐛 Troubleshooting

### Build Errors
**"Cannot find AVFoundation"**
- Solution: Clean build folder (Cmd+Shift+K), rebuild

### Runtime Errors
**"Hotkey not working"**
- Solution: Check Accessibility permission in System Settings

**"No speech detected"**
- Solution: Check microphone in System Settings → Sound → Input

**"Text doesn't appear"**
- Solution: Click in a text field first, ensure app has focus

---

## 📖 Documentation

- **Architecture:** `/Users/mrkkonecny/whispr/architecture/` (5 SOPs)
- **Progress Log:** `/Users/mrkkonecny/whispr/progress.md`
- **Task Plan:** `/Users/mrkkonecny/whispr/task_plan.md`

---

**Built with ❤️ for macOS**

Ready to dictate? Press Cmd+R! 🎤
