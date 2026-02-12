# Text Injection SOP

**Version:** 1.0  
**Last Updated:** 2026-02-07  
**Owner:** Swift macOS App (TextInjectionManager)

---

## Goal

Inject transcribed text into the currently active application at the cursor position, simulating natural typing or pasting.

---

## Input Schema

```json
{
  "text": {
    "content": "string (transcription to inject)",
    "length": "integer (character count)",
    "validated": "boolean (non-empty check)"
  },
  "target": {
    "activeApp": "string (bundle identifier)",
    "cursorPosition": "CGPoint (x, y)"
  }
}
```

---

## Process

### 1. **Pre-injection Checks**
```swift
Before injecting:
1. Verify text is not empty/whitespace only
2. Check Accessibility permissions granted
3. Verify active application is responsive
4. Get current cursor position (fallback: keyboard focus)
```

### 2. **Choose Injection Method**

**Method A: Pasteboard (Primary)**
```swift
Recommended approach:
1. Save current clipboard content (restore later)
2. Copy transcription to clipboard
3. Simulate Cmd+V (paste)
4. Wait for paste completion (~100ms)
5. Restore original clipboard content

Pros:
- Works in 99% of apps
- Preserves formatting
- Fast

Cons:
- Overwrites clipboard temporarily
```

**Method B: CGEvent Keyboard Simulation (Fallback)**
```swift
Alternative if pasteboard fails:
1. Create CGEvent for each character
2. Post keyboard events to system
3. Simulate typing character-by-character

Pros:
- No clipboard interference
- More "natural" appearance

Cons:
- Slower for long text
- May trigger rate limits in some apps
- Special characters need escape handling
```

**Method C: Accessibility API (Future)**
```swift
Most robust (for Phase 4+):
1. Get focused UI element via Accessibility
2. Set attributed string value directly
3. Insert at cursor position

Pros:
- No clipboard
- Instant
- Most reliable

Cons:
- Requires Accessibility permissions
- More complex implementation
```

### 3. **Execute Injection (Method A)**
```swift
Implementation:
1. let originalPasteboard = NSPasteboard.general.string(forType: .string)
2. NSPasteboard.general.clearContents()
3. NSPasteboard.general.setString(transcription, forType: .string)
4. Simulate Cmd+V using CGEvent:
   - Create CGEvent for Cmd key down
   - Create CGEvent for V key down
   - Post both events
   - Create CGEvent for V key up
   - Create CGEvent for Cmd key up
   - Post both events
5. usleep(100_000) // Wait 100ms
6. Restore clipboard:
   NSPasteboard.general.clearContents()
   if let original = originalPasteboard {
       NSPasteboard.general.setString(original, forType: .string)
   }
```

### 4. **Verify Injection**
```swift
Post-injection:
1. Check if paste command was successful
2. Log success/failure
3. Update UI to ready state
4. Clean up resources
```

---

## Output Schema

```json
{
  "injection": {
    "method": "pasteboard | cgevent | accessibility",
    "success": "boolean",
    "targetApp": "string (bundle ID)",
    "textLength": "integer",
    "timestamp": "ISO8601"
  },
  "performance": {
    "injectionTime": "float (milliseconds)",
    "clipboardRestored": "boolean"
  }
}
```

---

## Edge Cases

### Case 1: Accessibility Permission Denied
**Handling:**
- Check permission status before injection
- If denied → Show permission prompt
- Guide user to System Settings > Privacy & Security > Accessibility
- Do not attempt injection until granted

### Case 2: No Active Application
**Handling:**
- Detect if no app has keyboard focus
- Rare case (e.g., right after app launch)
- Show notification: "No text field active. Click where you want to type."
- Store transcription in clipboard as fallback

### Case 3: Clipboard Restoration Fails
**Handling:**
- If originalPasteboard is nil → Skip restoration
- If pasteboard.setString fails → Log warning
- User impact: Minor (clipboard unchanged)
- Not critical error

### Case 4: Target App Doesn't Accept Paste
**Handling:**
- Some apps block programmatic paste (rare)
- Detect: No text appears after paste command
- Fallback: Use CGEvent typing (Method B)
- If that fails → Show error

### Case 5: Very Long Text (>10,000 characters)
**Handling:**
- Pasteboard has size limits
- Split into chunks if needed
- Paste sequentially with small delays
- Or: Warn user and truncate

### Case 6: Special Characters / Emojis
**Handling:**
- Pasteboard method: Handles all Unicode correctly
- CGEvent method: May need special encoding
- Test: Ensure emojis, accents, symbols work

### Case 7: Text Field is Read-Only
**Handling:**
- No way to detect programmatically
- User will see no change
- Not our responsibility (user error)
- Transcription was successful, injection failed silently

---

## Dependencies

### macOS Frameworks
- **AppKit** (NSPasteboard, NSEvent)
- **CoreGraphics** (CGEvent, CGEventPost)
- **ApplicationServices** (Accessibility)

### System Permissions
- **Accessibility** (required for CGEvent posting)
  - Requested in Info.plist: NSAppleEventsUsageDescription

### Process Flow
```
Transcription → Text Injection → Active App
```

---

## Performance Requirements

- **Latency:** < 200ms from transcription completion to text appearance
- **Clipboard Restore:** < 50ms
- **CPU Usage:** < 1% during injection
- **Memory:** < 10MB

---

## Implementation Priority

### MVP (Phase 3)
- **Method A: Pasteboard + Cmd+V** ✅
  - Simplest, works everywhere
  - Acceptable clipboard flicker

### Future Enhancement (Phase 4+)
- **Method C: Accessibility API**
  - No clipboard interference
  - More robust
  - Direct text insertion

---

## Testing Checklist

- [ ] Text appears in TextEdit
- [ ] Text appears in Safari text field
- [ ] Text appears in Slack message box
- [ ] Text appears in Notes app
- [ ] Text appears in Terminal (if supported)
- [ ] Clipboard is restored correctly
- [ ] Special characters work (é, ñ, ü, etc.)
- [ ] Emojis work (😀, 👍, etc.)
- [ ] Long text (>1000 chars) works
- [ ] Rapid repeated injections don't break
