# Whisper Transcription SOP

**Version:** 1.0  
**Last Updated:** 2026-02-07  
**Owner:** Swift macOS App (TranscriptionManager)

---

## Goal

Call whisper.cpp to transcribe a WAV audio file into text, handle errors gracefully, and return clean transcription output.

---

## Input Schema

```json
{
  "audioFile": {
    "path": "string (absolute path to .wav file)",
    "exists": "boolean (verify before processing)",
    "readable": "boolean (check permissions)"
  },
  "options": {
    "model": "string (path to ggml-medium.bin)",
    "language": "string (auto-detect | en | es | fr | etc.)",
    "threads": "integer (4 recommended for M2)",
    "noTimestamps": true
  }
}
```

---

## Process

### 1. **Pre-flight Checks**
```swift
Before calling whisper.cpp:
1. Verify audio file exists and is readable
2. Verify model file exists (ggml-medium.bin)
3. Check file size > 0 bytes
4. Verify whisper.cpp binary exists and is executable
```

### 2. **Build Command**
```swift
Command structure:
/path/to/whisper.cpp/build/bin/whisper-cli \
  -m /path/to/models/ggml-medium.bin \
  -f /path/to/.tmp/audio_capture_TIMESTAMP.wav \
  -nt \      # No timestamps (cleaner output)
  -t 4 \     # 4 threads (optimal for M2)
  -l auto    # Auto-detect language

Optional flags:
  -l LANG    # Force specific language (en, es, fr, etc.)
  --print-colors # Colored output (if terminal)
```

### 3. **Execute Process**
```swift
Using Swift Process API:
1. Create Process instance
2. Set executable path
3. Set arguments array
4. Set up stdout/stderr pipes
5. Launch process
6. Wait for completion (timeout: 60 seconds)
7. Read output from pipes
```

### 4. **Parse Output**
```swift
whisper.cpp output format:
[00:00:00.000 --> 00:00:05.000]   This is the transcription text.

Parsing steps:
1. Read all stdout lines
2. Filter out system info lines (whisper_init, Metal, etc.)
3. Find lines containing "]" (transcript markers)
4. Extract text after "]"
5. Trim whitespace
6. Join multiple segments
7. Return clean text
```

### 5. **Post-processing**
```swift
Clean up the transcription:
1. Remove leading/trailing whitespace
2. Ensure proper spacing
3. Validate output is not empty
4. Return final text string
```

---

## Output Schema

```json
{
  "transcription": {
    "text": "string (final transcribed text)",
    "language": "string (detected language code)",
    "processingTime": "float (seconds)",
    "success": "boolean",
    "timestamp": "ISO8601"
  },
  "performance": {
    "audioLength": "float (seconds)",
    "realTimeFactor": "float (processing_time / audio_length)",
    "threadsUsed": "integer"
  }
}
```

---

## Edge Cases

### Case 1: Audio File Not Found
**Handling:**
- Check file existence before Process launch
- Error: "Audio file missing: [path]"
- Log error details
- Return nil transcription
- Show user notification: "Recording lost. Please try again."

### Case 2: whisper.cpp Binary Not Found
**Handling:**
- Verify binary path on app launch
- If missing → Show critical error
- Guide user to reinstall or download model
- Disable dictation until resolved

### Case 3: Model File Not Found
**Handling:**
- Check model path before transcription
- If missing → Offer to download automatically
- Show progress during download
- Retry transcription after download

### Case 4: Transcription Timeout (>60s)
**Handling:**
- Set Process timeout to 60 seconds
- If exceeded → Kill process
- Show error: "Transcription took too long. Try shorter audio."
- Clean up temp files

### Case 5: Empty/Silent Audio
**Handling:**
- whisper.cpp returns empty output
- Detect: transcription text is empty/whitespace only
- Show notification: "No speech detected. Try again."
- Don't inject empty text

### Case 6: Process Crashes
**Handling:**
- Catch Process termination errors
- Check termination status
- If abnormal (non-zero exit code):
  - Log stderr output
  - Show error: "Transcription failed. Please report this bug."
  - Don't retry automatically

### Case 7: Non-English Audio
**Handling:**
- whisper.cpp auto-detects language
- Parse language code from output
- Return detected language
- No special handling needed (99 languages supported)

---

## Dependencies

### External Binary
- **whisper.cpp/build/bin/whisper-cli**
  - Location: `whispr/whisper.cpp/build/bin/whisper-cli`
  - Model: `whispr/whisper.cpp/models/ggml-medium.bin`
  - Size: 1.43 GB

### Swift Frameworks
- **Foundation** (Process, Pipe, FileManager)

### File System
- Read access to audio file
- Read access to whisper.cpp binary
- Read access to model file

---

## Performance Requirements

- **Processing Speed:** < 0.5x real-time (for 10s audio, process in <5s)
- **CPU Usage:** < 80% during transcription
- **Memory:** < 2GB peak (model loading)
- **Timeout:** 60 seconds maximum

---

## Command Examples

### Basic Transcription (Auto-language)
```bash
./whisper-cli -m models/ggml-medium.bin -f audio.wav -nt -t 4
```

### Force English
```bash
./whisper-cli -m models/ggml-medium.bin -f audio.wav -nt -t 4 -l en
```

### Verbose Output (Debugging)
```bash
./whisper-cli -m models/ggml-medium.bin -f audio.wav -nt -t 4 --print-colors
```

---

## Testing Checklist

- [ ] Normal audio → Correct transcription
- [ ] Silent audio → Empty output handled
- [ ] Long audio (60s) → Completes successfully
- [ ] Missing audio file → Proper error
- [ ] Missing model file → Proper error
- [ ] Non-English audio → Correct language detection
- [ ] Process timeout → Handled gracefully
- [ ] Multiple rapid calls → No race conditions
- [ ] Memory cleanup → No leaks after transcription
