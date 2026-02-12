# Audio Capture SOP

**Version:** 1.0  
**Last Updated:** 2026-02-07  
**Owner:** Swift macOS App (AudioCaptureManager)

---

## Goal

Capture microphone input in real-time while the user holds down a keyboard shortcut, save as a WAV file suitable for whisper.cpp transcription.

---

## Input Schema

```json
{
  "trigger": {
    "event": "hotkey_pressed",
    "type": "hold_to_record"
  },
  "device": {
    "source": "default_microphone",
    "fallback": "system_default"
  }
}
```

---

## Process

### 1. **Initialize Audio Session**
```swift
// AVFoundation setup
- Configure AVAudioSession for recording
- Request microphone permissions (if not granted)
- Set audio format: 16kHz, mono, 16-bit PCM
- Create AVAudioEngine instance
```

### 2. **Start Recording on Hotkey Press**
```swift
When hotkey is pressed:
1. Check microphone permission status
2. If denied → Show permission prompt, abort
3. If granted:
   - Start AVAudioEngine
   - Create audio buffer
   - Begin capturing input
   - Show visual feedback (menu bar icon change)
```

### 3. **Capture Audio While Hotkey Held**
```swift
While hotkey is held:
- Continuously write audio data to buffer
- Monitor buffer size (max: 60 seconds)
- Update UI indicator (recording state)
```

### 4. **Stop Recording on Hotkey Release**
```swift
When hotkey is released:
1. Stop AVAudioEngine
2. Finalize audio buffer
3. Save buffer to temporary WAV file
4. Return file path for transcription
5. Update UI (processing state)
```

### 5. **Save as WAV File**
```swift
Output location: .tmp/audio_capture_TIMESTAMP.wav
Format specifications:
- Sample rate: 16000 Hz (whisper.cpp optimized)
- Channels: 1 (mono)
- Bit depth: 16-bit
- Format: PCM (uncompressed)
```

---

## Output Schema

```json
{
  "audioFile": {
    "path": "string (.tmp/audio_capture_1234567890.wav)",
    "format": "WAV (16-bit PCM)",
    "sampleRate": 16000,
    "channels": 1,
    "duration": "float (seconds)",
    "fileSize": "integer (bytes)",
    "timestamp": "ISO8601"
  },
  "metadata": {
    "recordingStarted": "ISO8601",
    "recordingEnded": "ISO8601",
    "device": "string (microphone name)"
  }
}
```

---

## Edge Cases

### Case 1: Microphone Permission Denied
**Handling:**
- Show macOS permission prompt
- If still denied → Display error notification
- Provide link to System Preferences
- Do not proceed with recording

### Case 2: No Microphone Found
**Handling:**
- Check for available audio input devices
- If none → Show error: "No microphone detected"
- Suggest user checks System Preferences > Sound

### Case 3: Recording Exceeds Max Duration (60s)
**Handling:**
- Auto-stop recording at 60 seconds
- Show notification: "Recording auto-stopped (max 60s)"
- Proceed to transcription with captured audio
- User can adjust max in preferences

### Case 4: Hotkey Released Too Quickly (<0.5s)
**Handling:**
- Treat as accidental tap
- Discard audio buffer
- Show brief notification: "Recording too short"
- Do not proceed to transcription

### Case 5: Audio Engine Fails to Start
**Handling:**
- Log error with details
- Show notification: "Audio recording failed. Please try again."
- Reset audio engine
- Allow retry

### Case 6: Disk Space Low
**Handling:**
- Check available disk space before recording
- If < 100MB → Show warning
- If < 10MB → Abort recording
- Clean up old temp files in .tmp/

---

## Dependencies

### macOS Frameworks
- **AVFoundation** (built-in)
  - `AVAudioSession`
  - `AVAudioEngine`
  - `AVAudioFile`
  - `AVAudioFormat`

### System Permissions
- **Microphone Access** (NSMicrophoneUsageDescription in Info.plist)

### File System
- Write access to `.tmp/` directory
- Temporary storage: ~1MB per 60 seconds of audio

---

## Performance Requirements

- **Latency:** < 200ms from hotkey press to recording start
- **CPU Usage:** < 5% during recording
- **Memory:** < 50MB peak
- **File Size:** ~960KB per minute (16kHz, mono, 16-bit)

---

## Testing Checklist

- [ ] Permission granted → Records successfully
- [ ] Permission denied → Shows proper error
- [ ] No microphone → Shows proper error
- [ ] 60-second recording → Auto-stops correctly
- [ ] Quick tap (<0.5s) → Discards correctly
- [ ] WAV file format → Readable by whisper.cpp
- [ ] Sample rate → Correct (16kHz)
- [ ] Audio quality → Clear and intelligible
