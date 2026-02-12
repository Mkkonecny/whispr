# Hotkey Management SOP

**Version:** 1.0  
**Last Updated:** 2026-02-07  
**Owner:** Swift macOS App (HotkeyManager)

---

## Goal

Register a global keyboard shortcut that triggers voice recording when pressed and stops recording when released, working across all macOS applications.

---

## Input Schema

```json
{
  "hotkey": {
    "keyCode": "integer (virtual key code)",
    "modifiers": "array (cmd, ctrl, opt, shift, fn)",
    "defaultCombination": "Cmd+Shift+Space"
  },
  "behavior": {
    "type": "hold_to_record",
    "cancelable": true
  }
}
```

---

## Process

### 1. **Initialize Hotkey System**
```swift
On app launch:
1. Load saved hotkey preference (UserDefaults)
2. If none → Use default: Cmd+Shift+Space
3. Check for conflicts with system shortcuts
4. Register global hotkey listener
```

### 2. **Register Global Hotkey**

**Using KeyboardShortcuts Library (Recommended)**
```swift
import KeyboardShortcuts

Extension in AppDelegate:
extension KeyboardShortcuts.Name {
    static let startDictation = Self("startDictation")
}

Setup:
KeyboardShortcuts.onKeyDown(for: .startDictation) { [weak self] in
    self?.startRecording()
}

KeyboardShortcuts.onKeyUp(for: .startDictation) { [weak self] in
    self?.stopRecording()
}
```

**Alternative: CGEventTap (Manual)**
```swift
// Lower-level approach if library doesn't work
let eventMask = (1 << CGEventType.keyDown.rawValue) | 
                (1 << CGEventType.keyUp.rawValue)
                
guard let eventTap = CGEvent.tapCreate(
    tap: .cgSessionEventTap,
    place: .headInsertEventTap,
    options: .defaultTap,
    eventsOfInterest: CGEventMask(eventMask),
    callback: hotkeyCallback,
    userInfo: nil
) else {
    // Failed to create tap (no Accessibility permission)
    return
}
```

### 3. **Handle Hotkey Press**
```swift
When hotkey is pressed (keyDown):
1. Check app state (not already recording)
2. Verify microphone permission
3. Trigger audio capture start
4. Update menu bar icon (visual feedback)
5. Play subtle sound effect (optional)
```

### 4. **Handle Hotkey Release**
```swift
When hotkey is released (keyUp):
1. Stop audio capture
2. Save audio file
3. Update menu bar icon (processing state)
4. Trigger transcription pipeline
5. Wait for transcription completion
6. Inject text
7. Reset UI to ready state
```

### 5. **Handle Cancel**
```swift
If user presses Escape while recording:
1. Stop audio capture immediately
2. Discard audio buffer
3. Don't proceed to transcription
4. Reset UI
5. Show brief notification: "Recording cancelled"
```

---

## Output Schema

```json
{
  "hotkeyEvent": {
    "type": "keyDown | keyUp",
    "shortcut": "string (Cmd+Shift+Space)",
    "timestamp": "ISO8601",
    "handled": "boolean"
  },
  "stateChange": {
    "from": "idle | recording | processing",
    "to": "idle | recording | processing",
    "trigger": "hotkey_press | hotkey_release | cancel"
  }
}
```

---

## Edge Cases

### Case 1: Accessibility Permission Denied
**Handling:**
- Global hotkeys require Accessibility permission
- On app launch, check permission status
- If denied:
  - Show permission prompt
  - Guide user to System Settings
  - Disable dictation until granted
- Retry check when app becomes active

### Case 2: Hotkey Conflict with System
**Handling:**
- macOS reserves some shortcuts (Cmd+Space, etc.)
- On registration, check if shortcut is available
- If conflict detected:
  - Show warning: "Shortcut conflicts with [System App]"
  - Suggest alternative (Cmd+Shift+Space)
  - Allow user to choose different combination

### Case 3: Hotkey Conflict with Other App
**Handling:**
- Can't detect this reliably
- If hotkey doesn't work:
  - Show troubleshooting tip
  - Suggest trying different combination
- User decision to change

### Case 4: Rapid Press/Release (<0.5s)
**Handling:**
- Treat as accidental activation
- Discard recorded audio
- Don't proceed to transcription
- Show subtle notification: "Too quick"

### Case 5: User Holds Hotkey Too Long (>60s)
**Handling:**
- Auto-stop recording at 60 seconds
- Proceed with transcription
- Show notification: "Max recording time reached"

### Case 6: Multiple Hotkey Presses While Processing
**Handling:**
- Ignore hotkey events while state = "processing"
- Show notification: "Still processing..."
- Queue is disabled (no buffering)

### Case 7: App Not in Focus
**Handling:**
- Global hotkeys work even when app is in background
- This is desired behavior
- Transcription injects into active app (not Whispr)

---

## Dependencies

### Swift Package
- **KeyboardShortcuts** (sindresorhus)
  - Add via SPM: `https://github.com/sindresorhus/KeyboardShortcuts`
  - Simplifies global hotkey management
  - Handles permissions automatically

### macOS Frameworks
- **AppKit** (NSEvent, if using manual approach)
- **CoreGraphics** (CGEvent)

### System Permissions
- **Accessibility** (NSAppleEventsUsageDescription)

---

## User Experience

### Visual Feedback States

**Idle (Ready)**
- Menu bar icon: Microphone (gray)
- Tooltip: "Press Cmd+Shift+Space to dictate"

**Recording**
- Menu bar icon: Microphone (red/pulsing)
- Tooltip: "Recording... Release to transcribe"

**Processing**
- Menu bar icon: Spinning/loading indicator
- Tooltip: "Transcribing..."

**Error**
- Menu bar icon: Microphone (yellow/warning)
- Tooltip: "Click for details"

---

## Preferences UI

Allow user to customize hotkey:
```
┌─────────────────────────────────┐
│ Dictation Hotkey:               │
│ ┌───────────────────────────┐   │
│ │  Cmd+Shift+Space          │   │
│ └───────────────────────────┘   │
│                                 │
│ [ Record Hotkey ]               │
│                                 │
│ ⚠️ Requires Accessibility       │
│    permission                   │
└─────────────────────────────────┘
```

---

## Testing Checklist

- [ ] Hotkey registers successfully
- [ ] Hotkey triggers recording (keyDown)
- [ ] Hotkey stops recording (keyUp)
- [ ] Works while app is in background
- [ ] Works in different apps (Safari, Notes, Slack)
- [ ] Accessibility permission prompt appears if needed
- [ ] User can customize hotkey in preferences
- [ ] Conflict detection works
- [ ] Cancel with Escape works
- [ ] Rapid press/release handled correctly
- [ ] 60-second auto-stop works
- [ ] Multiple rapid presses don't crash
- [ ] Menu bar icon updates correctly
