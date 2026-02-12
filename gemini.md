# 🧬 Project Constitution: Whispr

**Project Name:** Whispr  
**Type:** macOS Voice-to-Text Application  
**Status:** Initialization  
**Last Updated:** 2026-02-07

---

## 🎯 Project Mission

**North Star:** Build a privacy-first, system-wide voice-to-text dictation tool for macOS that works seamlessly in any application, activates via keyboard shortcut, and processes all audio locally without storing recordings or sending data to external services.

**Technology Decision:** whisper.cpp (C++ backend) + Swift macOS App (native frontend)  
**Privacy Level:** 100% on-device processing  
**Target Platform:** macOS (Apple Silicon M1+)  
**Languages Supported:** All languages supported by Whisper (99+)

---

## 📊 Data Schema

### Layer 1: Audio Capture (Input)
```json
{
  "audioStream": {
    "format": "WAV (16-bit PCM)",
    "sampleRate": 16000,
    "channels": 1,
    "source": "microphone",
    "duration": "variable (while hotkey held)",
    "bufferSize": 4096
  }
}
```

### Layer 2: Whisper Processing (whisper.cpp)
```json
{
  "whisperInput": {
    "audioFile": "string (path to .tmp/audio_capture.wav)",
    "model": "string (e.g., 'models/ggml-medium.bin')",
    "language": "auto-detect | specific_code",
    "threads": "integer (CPU cores to use)"
  }
}
```

### Layer 3: Transcription Output
```json
{
  "transcription": {
    "text": "string (final transcribed text)",
    "confidence": "float (if available)",
    "language": "string (detected language code)",
    "processingTime": "float (seconds)",
    "timestamp": "ISO8601"
  }
}
```

### Layer 3.5: Text Cleanup (NEW - Filler Word Removal)
```json
{
  "cleanup": {
    "mode": "fast | polish",
    "rawText": "string (original transcription)",
    "cleanedText": "string (after filler removal)",
    "removedFillers": ["um", "uh", "like"],
    "grammarFixed": "boolean",
    "processingTime": "float (seconds)"
  }
}
```

### Layer 4: Text Injection (Final Delivery)
```json
{
  "injection": {
    "method": "CGEvent | Accessibility | Clipboard",
    "targetApp": "string (active application bundle ID)",
    "cursorPosition": "CGPoint (x, y)",
    "success": "boolean"
  }
}
```

---

## 🏗️ Architectural Invariants

### Layer 1: Architecture
- All SOPs live in `/architecture/` as markdown files
- Logic changes require SOP updates first

### Layer 2: Navigation
- Decision-making layer (this AI agent)
- Routes data between SOPs and Tools
- Does not perform complex tasks directly

### Layer 3: Tools
- Deterministic Python scripts in `/tools/`
- Environment variables in `.env`
- Intermediate files in `.tmp/`

---

## ⚖️ Behavioral Rules

### Privacy Rules (MANDATORY)
1. **NO Cloud Processing:** All transcription happens locally on the Mac
2. **NO Audio Storage:** Audio files are deleted immediately after transcription
3. **NO Data Transmission:** Zero network requests to external services
4. **NO Telemetry:** No usage tracking, analytics, or crash reporting to external servers
5. **NO Logs:** Do not log audio content or transcriptions to persistent files

### User Experience Rules
1. **Keyboard Activation:** Only activate via user-defined keyboard shortcut (no auto-listening)
2. **Visual Feedback:** Show subtle menu bar indicator when recording
3. **Universal Compatibility:** Must work in ALL macOS applications
4. **Instant Insertion:** Text appears at cursor position immediately after transcription
5. **Non-Intrusive:** Menu bar app only (no Dock icon)
6. **Cancellable:** User can release hotkey early to cancel recording
7. **Text Cleanup (NEW):** 
   - **Fast Mode:** Raw transcription (no cleanup, instant)
   - **Polish Mode:** Remove filler words + fix grammar (2-5 seconds)
   - User-selectable mode in preferences
   - Filler words to remove: "um," "uh," "like," "you know," stutters

### System Behavior
1. **Graceful Degradation:** If Whisper fails, show error but don't crash
2. **Permission Handling:** Clear prompts for Microphone and Accessibility access
3. **Model Management:** Auto-download Whisper model on first run if missing
4. **Performance:** Transcription should feel near-real-time (< 3 seconds for 10-second clip)

### "Do Not" Rules
- Do NOT store audio files after transcription completes
- Do NOT send any data over the network
- Do NOT run transcription when hotkey is not pressed
- Do NOT show in application switcher (Cmd+Tab)
- Do NOT auto-update models without user consent

---

## 🔐 Integration Points

### External Dependencies
1. **whisper.cpp**
   - Source: `https://github.com/ggerganov/whisper.cpp`
   - Installation: Homebrew or compile from source
   - Models: Download `ggml-medium.bin` (~1.5GB)
   - No API keys required ✅

2. **Swift Libraries (SPM)**
   - `KeyboardShortcuts` - Global hotkey management
   - `AVFoundation` - Audio capture (built-in to macOS)
   - `AppKit` - macOS native UI (built-in)

3. **Text Cleanup Layer (Optional, for Polish Mode)**
   - **Option A:** Llama 3-3B/8B via MLX (AI-powered cleanup)
     - Install: `pip install mlx-lm` or use Ollama
     - Models: Hugging Face quantized models
     - Privacy: 100% local processing
   - **Option B:** Rule-based regex filter (lightweight)
     - No dependencies
     - Instant processing

### System Integrations
1. **macOS Permissions:**
   - Microphone Access (AVFoundation)
   - Accessibility (for global hotkeys + text injection)
   - Screen Recording (optional, for enhanced text injection)

2. **File System:**
   - `.tmp/` - Temporary audio file storage (auto-cleanup)
   - `~/Library/Application Support/Whispr/models/` - Whisper models
   - `~/Library/Preferences/com.whispr.plist` - User preferences

### No External APIs
- NO API keys needed
- NO cloud services
- NO authentication required

---

## 📝 Maintenance Log

| Date | Change | Reason |
|------|--------|--------|
| 2026-02-07 | Constitution initialized | B.L.A.S.T. Protocol 0 |
| 2026-02-07 | Data Schema defined | Phase 1 Blueprint complete |
| 2026-02-07 | Technology decision: whisper.cpp + Swift | Privacy requirement analysis |
| 2026-02-07 | Behavioral rules established | User requirements capture |
| 2026-02-07 | Added filler word removal feature | Competitive analysis (Glaido) |
| 2026-02-07 | Added Layer 3.5: Text Cleanup to schema | User request + market research |
| 2026-02-07 | Implementation strategy: Fast Mode first | Phased rollout decision |
| 2026-02-07 | Cleanup tech: Llama only (no regex) | User preference for AI reliability |

---

## 🚨 Known Constraints

### Implementation Strategy (2026-02-07)

**Phased Rollout:**
1. **Phase 2-3: MVP (Fast Mode Only)**
   - whisper.cpp transcription only
   - No text cleanup
   - Raw transcription → Direct injection
   - Goal: Prove the pipeline works end-to-end

2. **Phase 4+: Polish Mode (Text Cleanup)**
   - Add Llama 3-3B/8B via MLX for filler removal
   - Grammar & punctuation fixes
   - User toggles between Fast/Polish in preferences
   - **NO regex-based cleanup** (user decision: AI-only for reliability)

**Rationale:**
- Fast Mode simpler to build and test
- Llama integration can be added without breaking existing functionality
- Users get working dictation immediately
- AI cleanup is opt-in feature

### Technical Constraints

[To be populated during research and development]
