# 🔍 Research Findings: Whispr

**Last Updated:** 2026-02-07

---

## 📚 Technology Research

### Voice-to-Text Options (Updated: 2026-02-07)

#### ✅ **RECOMMENDED: whisper.cpp + Swift macOS App**
**Score: 10/10 for Privacy + Performance**

**Why This Stack:**
- **100% Local Processing:** No data leaves the Mac
- **Apple Silicon Optimized:** Uses Metal for GPU acceleration
- **Fast:** Medium model transcribes in near real-time on M-series chips
- **Multi-language:** Supports 99+ languages out of the box
- **Proven:** Used by SuperWhisper, MacWhisper, WhisperClip

**Architecture:**
1. **whisper.cpp** - C++ port of OpenAI Whisper (backend)
   - Optimized with ARM NEON + Metal acceleration
   - Command-line tool for transcription
   - Models: tiny, base, small, medium, large (recommend medium for balance)
   
2. **Swift macOS App** - Native UI wrapper (frontend)
   - Global keyboard shortcut listener
   - Real-time audio capture
   - Text injection into active apps
   - Menu bar interface

**Performance on Apple Silicon:**
- M1/M2: 2-3 minutes for 10-min audio
- M3/M4: 50 seconds to 1 minute for 10-min audio
- **Real-time transcription:** Possible with streaming + medium model

#### ⚠️ **REJECTED: OpenAI Whisper API**
- Sends audio to OpenAI servers
- Violates privacy requirement
- Requires internet connection

#### 🔬 **Alternative: Apple's Native Speech Recognition**
- Built into macOS (Speech framework)
- 100% on-device
- **Limitation:** Limited language support, less accurate than Whisper
- **Use case:** Fallback option only

#### 📊 **Comparison Matrix**

| Solution | Privacy | Speed | Accuracy | Multi-lang | Cost |
|----------|---------|-------|----------|------------|------|
| whisper.cpp | ✅ 100% | ⚡ Fast | 🎯 Excellent | 🌍 99+ | 💰 Free |
| OpenAI API | ❌ Cloud | ⚡ Very Fast | 🎯 Excellent | 🌍 99+ | 💰 Paid |
| Apple Speech | ✅ 100% | ⚡ Fast | ⚠️ Good | ⚠️ Limited | 💰 Free |

---

## 🔍 Competitive Analysis: Glaido

### Overview (2026-02-07)
Glaido is a direct competitor offering system-wide dictation for macOS. Analysis reveals their architecture and unique features.

### Technology Stack (Inferred)
**Primary Transcription:**
- Uses **local/open-source models** (likely whisper.cpp or WhisperKit)
- Explicitly states: **"Your data is never shared with big labs"**
- **"Optional local processing"** for maximum privacy
- macOS only (optimized for Apple Silicon)

**Text Cleanup Layer (NEW INSIGHT):**
- **Filler Word Removal:** Automatically removes "um," "uh," "like"
- **AI Auto-Edits:** Polished grammar & punctuation
- **Two Modes:**
  1. **Lightning Mode:** Raw, ultra-fast transcription (no cleanup)
  2. **Standard Mode:** AI-polished output (includes cleanup)

**Likely Implementation:**
- Uses local LLM (probably Llama 3-3B/8B via MLX) for text cleanup
- Privacy-compliant: All processing stays local
- Fast enough for "real-time transformation"

### Key Features We Should Consider
1. ✅ **Filler Word Removal** - MUST HAVE
   - Removes: "um," "uh," "like," "you know," stutters
   - Example: "Um, can you like send me that file?" → "Can you send me that file?"
   
2. ✅ **Dual Mode Option**
   - Fast Mode: Raw transcription (instant)
   - Polish Mode: Cleanup + formatting (slightly slower)
   
3. ✅ **Custom Formatting**
   - Can transform speech into emails, bullet points, etc.
   - Uses prompt-based instructions

4. ✅ **System-Wide Hotkey** (same as our requirement)

5. ✅ **GDPR Compliant** (privacy-first, like our requirement)

### Pricing Model
- Free: 2,000 words/week
- Pro ($20/month): Unlimited usage

### Technical Implementation for Whispr
Based on Glaido's success, we should implement:

**Pipeline:**
```
Audio → whisper.cpp → Raw Text → [NEW] Local LLM Cleanup → Polished Text → Inject
```

**Recommended Cleanup Stack:**
1. **Option A: Llama 3-3B/8B via MLX** (full AI cleanup)
   - Removes fillers
   - Fixes grammar
   - Adds punctuation
   - ~2-3 second processing time on M1+
   
2. **Option B: Rule-Based Filter** (lightweight)
   - Simple regex to remove common fillers
   - No AI needed
   - Instant processing
   - Less accurate but faster

3. **Option C: Hybrid** (recommended for Whispr)
   - Fast mode: Rule-based (instant)
   - Polish mode: Local LLM (3-5 sec)
   - User toggles via preferences

---

## 🌐 API & Integration Research

### Key Resources (2026-02-07)

#### 1. **whisper.cpp** (Backend Engine)
- **Repo:** `https://github.com/ggerganov/whisper.cpp`
- **Installation:** Homebrew or build from source
- **Models:** Download via `./models/download-ggml-model.sh`
- **Usage:** Command-line interface `./main -m models/ggml-medium.bin -f audio.wav`

#### 2. **Swift Libraries for Global Hotkeys**
- **KeyboardShortcuts:** `https://github.com/sindresorhus/KeyboardShortcuts`
  - Easy SPM integration
  - User-friendly shortcut recorder UI
- **HotKey:** Alternative lightweight library
- **CGEventTap:** Low-level macOS API (requires Accessibility permissions)

#### 3. **Audio Capture (macOS)**
- **AVFoundation:** Native Swift framework for microphone access
- **AVAudioEngine:** Real-time audio streaming
- **AudioUnit:** Low-latency audio processing

#### 4. **Text Injection**
- **CGEvent:** Simulate keyboard events to paste text
- **Accessibility API:** Direct text insertion into active apps
- **Clipboard + Paste:** Fallback method

#### 5. **Reference Implementations**
- **SuperWhisper:** Commercial (closed source) but sets the standard
- **MacWhisper:** Uses WhisperKit (CoreML approach)
- **faster-whisper-hotkey:** Python package (reference for workflow)
- **WhisperKit:** Swift package using CoreML (alternative to whisper.cpp)

#### 6. **Text Cleanup / Filler Word Removal**
- **Llama 3-3B/8B via MLX:** Local LLM for AI-powered cleanup
  - Repo: `https://github.com/ml-explore/mlx-examples`
  - Install: `pip install mlx-lm`
  - Models: Hugging Face (quantized for efficiency)
  
- **Rule-Based Approach:** Simple regex filter
  - Pattern matching for "um," "uh," "like," "you know"
  - Lightweight, instant processing
  - No AI dependencies

- **whisper-timestamped:** Get word-level timestamps
  - Enables precise filler word detection
  - Works with whisper.cpp output

---

## 🧪 Testing Discoveries

[To be populated during development]

---

## ⚠️ Constraints & Limitations

### Technical Constraints (2026-02-07)

1. **macOS Permissions Required:**
   - Microphone Access
   - Accessibility (for global hotkeys + text injection)
   - Screen Recording (may be needed for some text injection methods)

2. **Hardware Requirements:**
   - **Minimum:** M1 Mac with 8GB RAM (for base/small models)
   - **Recommended:** M3/M4 with 16GB RAM (for medium/large models)
   - **Storage:** ~1-3GB for Whisper models

3. **Performance Trade-offs:**
   - Smaller models (tiny/base): Fast but less accurate
   - Medium model: Best balance (recommended)
   - Large model: Most accurate but slower, needs 16GB+ RAM

4. **Privacy Constraints (User Requirements):**
   - ✅ No cloud APIs allowed
   - ✅ No audio storage
   - ✅ All processing must be local
   - ✅ No telemetry or analytics

5. **Behavioral Constraints:**
   - Must work in ALL macOS apps (Safari, Notes, Slack, etc.)
   - Must activate via keyboard shortcut only
   - Must insert text directly at cursor position
   - Should NOT show in Dock (menu bar app only)

---

## 💡 Key Insights

- **2026-02-07:** Project name chosen: "Whispr"
- **2026-02-07:** Target platform: macOS
- **2026-02-07:** User previously researched voice-to-text naming and technology

---

## 🔗 Useful Resources

### Documentation
- whisper.cpp GitHub: https://github.com/ggerganov/whisper.cpp
- Apple AVFoundation: https://developer.apple.com/av-foundation/
- Swift KeyboardShortcuts: https://github.com/sindresorhus/KeyboardShortcuts
- macOS Accessibility API: https://developer.apple.com/documentation/accessibility

### Similar Projects
- MacWhisper (reference): https://goodsnooze.gumroad.com/l/macwhisper
- SuperWhisper (gold standard): https://superwhisper.com
- faster-whisper-hotkey: https://pypi.org/project/faster-whisper-hotkey/

### Technical Guides
- whisper.cpp on macOS: https://github.com/ggerganov/whisper.cpp#quick-start
- Global Hotkeys in Swift: Stack Overflow threads
- Text Injection on macOS: CGEvent documentation
