# Error Handling & Self-Annealing SOP

**Version:** 1.0  
**Last Updated:** 2026-02-07  
**Owner:** All Modules (WhisprApp)

---

## Goal

Implement graceful error handling that fails safely, provides useful feedback to users, and learns from errors to prevent recurrence (self-annealing).

---

## Input Schema

```json
{
  "error": {
    "domain": "string (AudioCapture | Transcription | TextInject | Hotkey)",
    "type": "string (permission | notFound | timeout | crash | etc.)",
    "message": "string (error description)",
    "details": "dict (stack trace, context)",
    "timestamp": "ISO8601"
  }
}
```

---

## Process

### 1. **Error Classification**

**Critical Errors (App Cannot Continue)**
```
- Missing whisper.cpp binary
- Missing model file
- No Accessibility permission (after user denies)
- Filesystem unwritable

Action: Show modal error, disable features, guide to fix
```

**Recoverable Errors (Retry Possible)**
```
- Microphone permission denied (can request again)
- Network timeout (for future cloud features)
- Transcription process crash (can retry)
- Disk space low (can clean up)

Action: Show notification, suggest fix, allow retry
```

**User Errors (Not Our Fault)**
```
- No speech in audio (user was silent)
- Audio too short (<0.5s)
- Target text field is read-only

Action: Show helpful tip, don't log as error
```

**Transient Errors (Ignore/Retry)**
```
- Audio buffer underrun (rare, retry)
- CGEvent post failed (retry once)

Action: Retry automatically, log if persistent
```

### 2. **Error Logging**

**Log Structure**
```swift
struct ErrorLog {
    let timestamp: Date
    let domain: ErrorDomain
    let type: ErrorType
    let message: String
    let userInfo: [String: Any]
    let stackTrace: String?
}

Save to: ~/Library/Logs/Whispr/errors.log
```

**What to Log**
- All errors except transient
- User actions leading to error
- System state (mic permission, disk space, etc.)
- whisper.cpp output if transcription failed

**What NOT to Log**
- Audio content (privacy!)
- Transcription text (privacy!)
- User's clipboard content

### 3. **User Notifications**

**Error Notification Levels**

**Level 1: Silent (No UI)**
```swift
// Transient errors, auto-recovered
- Log to file only
- No user notification
```

**Level 2: Subtle (Menu Bar Icon)**
```swift
// Recoverable errors
- Change menu bar icon to warning state
- Show tooltip with brief message
- Click for details
```

**Level 3: Notification Banner**
```swift
// Important but not critical
- macOS notification banner
- Title: Brief error
- Body: What happened + suggested action
- Action button: "Fix" (opens preferences)
```

**Level 4: Modal Alert**
```swift
// Critical errors only
- Blocks interaction
- Clear explanation
- Actionable steps to resolve
- "Quit" or "Open System Settings" buttons
```

### 4. **Self-Annealing Logic**

**Learning from Errors**

**Pattern 1: Permission Denied**
```swift
On first microphone denial:
1. Show permission prompt
2. If denied again → Don't ask repeatedly
3. Update SOPs: Add to "Known Constraints"
4. Update UI: Disable record button, show fix guide

Auto-fix:
- Check permission on app launch
- If granted later → Re-enable features
```

**Pattern 2: whisper.cpp Path Changed**
```swift
On "binary not found":
1. Search common locations
2. Prompt user to locate binary
3. Save new path to preferences
4. Update SOPs wit new default path

Auto-fix:
- On next launch, verify path before showing error
```

**Pattern 3: Model Download Failed**
```swift
On missing model:
1. Offer automatic download
2. Show progress bar
3. Retry on failure
4. Update SOPs: Document download URL

Auto-fix:
- Background check for model on launch
- Prevent user from starting dictation until ready
```

**Pattern 4: Repeated Transcription Failures**
```swift
If whisper.cpp fails 3+ times:
1. Run diagnostic:
   - Test with known-good audio file
   - Check model integrity
   - Verify binary works standalone
2. Log diagnostic results
3. Show user report with details
4. Suggest reinstall if corrupted

Auto-fix:
- Maintain health check state
- Disable buggy features until fixed
```

---

## Output Schema

```json
{
  "errorHandling": {
    "handled": "boolean",
    "recovery": "recovered | failed | user_action_required",
    "notification": "none | subtle | banner | modal",
    "logged": "boolean",
    "retryScheduled": "boolean"
  },
  "annealingAction": {
    "sopUpdated": "boolean",
    "configurationChanged": "boolean",
    "featureDisabled": "boolean",
    "autoFixApplied": "boolean"
  }
}
```

---

## Edge Cases

### Case 1: Error During Error Handling
**Handling:**
- Catch exceptions in error handler itself
- Log to system console as last resort
- Show generic "Something went wrong" modal
- Include bug report link

### Case 2: Log File Grows Too Large (>10MB)
**Handling:**
- Rotate logs weekly
- Keep last 4 weeks
- Compress old logs
- Delete logs older than 1 month

### Case 3: User Spam-Clicks After Error
**Handling:**
- Debounce user actions (1-second cooldown)
- Ignore rapid retries
- Show: "Please wait..."

### Case 4: Simultaneous Errors
**Handling:**
- Queue notifications
- Show most critical first
- Batch similar errors
- Don't spam user

---

## Dependencies

### macOS Frameworks
- **Foundation** (Error protocol, logging)
- **UserNotifications** (Notification banners)
- **AppKit** (NSAlert for modals)

### File System
- Write access to ~/Library/Logs/Whispr/

---

## Error Messages - Best Practices

### Good Error Message
```
❌ "Microphone permission is required for dictation."
✅ Action: "Open System Settings"
```

### Bad Error Message
```
❌ "Error -1004: AVAudioEngine failed to initialize"
(Too technical, no action)
```

### Template
```
[What happened] + [Why] + [What to do]

Example:
"Recording failed because your microphone is in use by another app. 
Close other apps using the microphone and try again."
```

---

## Testing Checklist

- [ ] Microphone permission denied → Proper prompt
- [ ] whisper.cpp not found → Clear error + fix action
- [ ] Model not found → Offer download
- [ ] Transcription timeout → Notification + retry option
- [ ] Disk full → Warning before recording
- [ ] Silent audio → "No speech detected" tip
- [ ] Crash recovery → App restarts safely
- [ ] Error logs → Created correctly
- [ ] Privacy → No sensitive data in logs
- [ ] Self-annealing → Errors don't repeat unnecessarily

---

## Monitoring & Analytics (Future)

Phase 4+ only (if user opts in):
- Crash reporting (anonymized)
- Error frequency tracking
- Performance metrics
- Always opt-in, never automatic
