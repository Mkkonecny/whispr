# 📋 Task Plan: Whispr

**Created:** 2026-02-07  
**Status:** Phase 0 - Discovery

---

## 🗺️ B.L.A.S.T. Phases

### ✅ Phase 0: Initialization
- [x] Create `gemini.md`
- [x] Create `task_plan.md`
- [x] Create `findings.md`
- [x] Create `progress.md`
- [ ] Create directory structure
- [ ] Answer Discovery Questions
- [ ] Define Data Schema in `gemini.md`
- [ ] Get Blueprint Approval

---

### ✅ Phase 1: B - Blueprint (Vision & Logic)
**Status:** ✅ COMPLETE  
**Completed:** 2026-02-07

#### Goals:
- [x] Define North Star outcome
- [x] Identify all integrations
- [x] Establish Source of Truth
- [x] Define Delivery Payload
- [x] Set Behavioral Rules
- [x] Research best voice-to-text technologies
- [x] Finalize Data Schema
- [x] Resolve privacy constraint conflict

#### Deliverables:
- ✅ Updated `gemini.md` (Project Constitution)
- ✅ Updated `findings.md` (Research documentation)
- ✅ Technology Decision: whisper.cpp + Swift
- ✅ Data Schema: 4-layer pipeline defined

---

### ✅ Phase 2: L - Link (Connectivity)
**Status:** ✅ COMPLETE  
**Completed:** 2026-02-07

#### Goals:
- [x] Install whisper.cpp (Homebrew or build from source)
- [x] Download Whisper medium model
- [x] Verify whisper.cpp works with test audio
- [x] Create handshake test scripts
- [x] Document any integration issues

#### Success Criteria:
- ✅ whisper.cpp can transcribe a test WAV file
- ✅ Metal acceleration working on M2
- ✅ Performance: 0.4x real-time (faster than audio!)
- ✅ Test script created and passing

#### Deliverables:
- ✅ whisper.cpp installed with Metal support
- ✅ ggml-medium.bin model (1.43GB, 99 languages)
- ✅ `tools/test_whisper.py` verification script
- ✅ Transcription tested and working perfectly

---

### 🟡 Phase 3: A - Architect (The 3-Layer Build)
**Status:** In Progress (Layer 1 & 2 Complete)  
**Started:** 2026-02-07

#### Goals:
- [x] **SOPs to Create (architecture/):**
  - [x] `audio_capture_sop.md` - How to capture microphone input
  - [x] `whisper_transcription_sop.md` - How to call whisper.cpp
  - [x] `text_injection_sop.md` - How to inject text into apps
  - [x] `hotkey_management_sop.md` - How to handle keyboard shortcuts
  - [x] `error_handling_sop.md` - Self-annealing error recovery
  - [x] ~~`text_cleanup_sop.md`~~ - DEFERRED to Phase 4+ (Polish Mode)

- [x] **Tools to Build (tools/):**
  - [x] `test_whisper.py` - Verify whisper.cpp installation (from Phase 2)
  - [ ] `test_audio.py` - Test microphone capture
  - [ ] `test_injection.py` - Test text injection methods
  - [ ] `cleanup_tmp.py` - Auto-cleanup temporary files

- [x] **Swift macOS App (MVP - Fast Mode Only):**
  - [x] Project structure created
  - [x] Menu bar app setup (no Dock icon)
  - [x] Audio capture module (AVFoundation)
  - [x] Whisper integration (Process wrapper for whisper.cpp)
  - [x] Text injection module (Clipboard + Cmd+V)
  - [x] Hotkey management (CGEvent tap)
  - [x] Error handling (4-level notifications)
  - [x] Basic preferences window
  - [ ] ~~Xcode project file~~ - User to create in Xcode
  - [ ] Build and test in Xcode
  - [ ] ~~Llama cleanup integration~~ - DEFERRED to Phase 4+
  - [ ] ~~Mode toggle (Fast/Polish)~~ - DEFERRED to Phase 4+

#### Success Criteria:
- [x] All SOPs documented with schemas (except cleanup)
- [x] Python test tool for whisper.cpp working
- [x] Swift app code complete (all managers implemented)
- [ ] App builds successfully in Xcode
- [ ] End-to-end flow tested: Hotkey → Record → Transcribe → Inject
- [ ] **Fast Mode working end-to-end** (no cleanup needed yet)

#### Current Status:
- ✅ Layer 1 (SOPs): Complete
- ✅ Layer 2 (Code): Complete
- ⏳ Layer 3 (Testing): Awaiting user to open in Xcode

---

### 🟣 Phase 4: S - Stylize (Refinement & UI)
**Status:** Awaiting Architecture completion  
**Blockers:** MVP not complete

#### Goals (MVP):
- [ ] Menu bar icon design
- [ ] Status indicator animations (recording, processing)
- [ ] Preferences UI polish
- [ ] Error message formatting
- [ ] User onboarding flow
- [ ] First-run setup (permissions, model download)

#### Goals (Future - Polish Mode):
- [ ] **Llama 3-3B integration via MLX**
- [ ] Text cleanup SOP (`text_cleanup_sop.md`)
- [ ] Mode toggle UI (Fast vs Polish)
- [ ] Cleanup preferences (aggressiveness slider)
- [ ] Before/after preview
- [ ] Custom filler word dictionary

---

### 🔴 Phase 5: T - Trigger (Deployment)
**Status:** Not Started  
**Blockers:** Stylization not complete

#### Goals:
- [ ] Prepare deployment package
- [ ] Set up automation triggers
- [ ] Finalize documentation
- [ ] Production release

---

## 🎯 Current Focus

**✅ Phase 1 Complete:** Blueprint approved  
**✅ Phase 2 Complete:** whisper.cpp installed and tested

**➡️ NEXT: Phase 3 - Architect (The 3-Layer Build)**

### Immediate Next Steps:
1. Create SOPs in `architecture/` for audio capture, transcription, text injection
2. Create Swift Xcode project
3. Implement basic audio capture
4. Integrate whisper.cpp via Process
5. Implement text injection
6. Create end-to-end MVP flow

---

## 📌 Notes

- Project is applying B.L.A.S.T. to existing voice-to-text app concept
- Previous conversations referenced Whisper/fastest voice-to-text tech
