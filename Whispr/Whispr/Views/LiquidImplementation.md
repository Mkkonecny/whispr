# Liquid Glass Implementation Guide

> **Purpose**: This document is the authoritative reference for how the recording bar's "liquid glass" visual effect is built. Use it as a guide for future changes or as a fallback if the effect breaks.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Layer Stack (Inside → Out)](#layer-stack)
3. [Window Setup (RecordingWindow)](#window-setup)
4. [Outer Ring Layer](#outer-ring-layer)
5. [Glass Blur Layer (SwiftUI Material)](#glass-blur-layer)
6. [Tint Overlay Layer](#tint-overlay-layer)
7. [Inner Edge Stroke](#inner-edge-stroke)
8. [Foreground Content Layer](#foreground-content-layer)
9. [AppKitGlassHost Fallback (NSVisualEffectView)](#appkitglasshost-fallback)
10. [Color Scheme Adaptation (Light / Dark)](#color-scheme-adaptation)
11. [Glass Style Preference ("clear" vs "tinted")](#glass-style-preference)
12. [Sizing & Geometry](#sizing--geometry)
13. [Animations](#animations)
14. [Common Pitfalls & Fixes](#common-pitfalls--fixes)

---

## Architecture Overview

The recording bar is a floating, transparent macOS panel (`NSPanel`) that overlays all other windows. Inside it, a SwiftUI `RecordingBarView` renders a capsule-shaped element with multiple visual layers stacked in a `ZStack`. Each layer is responsible for one aspect of the glass aesthetic.

```
┌──────────────────────────────────────────────────┐
│  RecordingWindow (NSPanel)                       │
│  background: .clear │ hasShadow: false           │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  RecordingBarView  (SwiftUI)               │  │
│  │                                            │  │
│  │  ZStack {                                  │  │
│  │    1. Outer Ring    (Capsule strokeBorder)  │  │
│  │       └── Thin edge stroke overlay          │  │
│  │    2. Content Group                        │  │
│  │       ├── Tint overlay  (Capsule fill)     │  │
│  │       ├── Blur material (.ultraThinMaterial)│  │
│  │       ├── Inner edge stroke overlay        │  │
│  │       └── Foreground (Logo + Visualizer)   │  │
│  │  }                                         │  │
│  └────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────┘
```

> [!IMPORTANT]
> The glass effect requires the **window itself** to be fully transparent (`.clear` background, no shadow, non-opaque). Without this, `NSVisualEffectView` and `.ultraThinMaterial` cannot sample the content behind the window.
---

## Layer Stack

The layers are listed from **back (bottom of ZStack)** to **front (top of ZStack)**:

| Z-Order | Layer | Shape | Purpose |
|---------|-------|-------|---------|
| 1 (back) | Outer Ring | `Capsule().strokeBorder` | Solid background border; leaves center transparent so blur can sample through |
| 1a | Edge Stroke | `Capsule().strokeBorder` | Hairline (1pt) border for definition |
| 2 | Blur Material | `Capsule().fill(.ultraThinMaterial)` | Live frosted-glass blur of content behind the window |
| 3 | Tint Overlay | `Capsule().fill(Color.accentColor.opacity(...))` | User's accent color wash (only when `glassStyle == "tinted"`) |
| 4 | Inner Edge Stroke | `Capsule().strokeBorder(...)` | Thin inner highlight at 0.9pt for depth |
| 5 (front) | Foreground Content | `HStack { LogoView, VisualizerBars }` | The actual interactive UI elements |

---

## Window Setup (RecordingWindow)

File: `RecordingWindow.swift`

The window is an `NSPanel` subclass configured to be invisible and non-interactive:

```swift
// RecordingWindow.init(contentView:)
super.init(
    contentRect: NSRect(x: 0, y: 0, width: 160, height: 60),
    styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
    backing: .buffered,
    defer: false
)

self.isFloatingPanel = true
self.level = .floating
self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
self.backgroundColor = .clear         // ← CRITICAL for glass
self.hasShadow = false                // ← No system shadow
self.isOpaque = false                 // ← Allow behind-window sampling
self.ignoresMouseEvents = true        // ← Click-through
```

The hosting view also has its shadow disabled:

```swift
let hostingView = NSHostingView(rootView: contentView)
hostingView.wantsLayer = true
hostingView.layer?.backgroundColor = .clear
hostingView.layer?.shadowOpacity = 0
hostingView.layer?.shadowRadius = 0
```

### Why these settings matter

| Property | Value | Why |
|----------|-------|-----|
| `backgroundColor` | `.clear` | Enables `.ultraThinMaterial` / `NSVisualEffectView` to sample the desktop behind the window |
| `hasShadow` | `false` | Prevents macOS from drawing a default panel shadow that breaks the "floating glass" look |
| `isOpaque` | `false` | Tells the compositing engine this window has transparency |
| `ignoresMouseEvents` | `true` | The bar is display-only; clicks pass through to whatever is underneath |
| `shadowOpacity/Radius` | `0` | Extra safety — removes any layer-level shadow on the hosting view |

> [!WARNING]
> If any of these properties are set incorrectly (especially `backgroundColor` or `isOpaque`), the blur will stop being "live" and instead show a frozen/black background.

---

## Outer Ring Layer

The outer ring serves two purposes:
1. Creates a **solid border** around the capsule for visual definition
2. Leaves the **center area transparent** so the blur material behind it can sample through

```swift
// Layer 1: Solid ring
Capsule()
    .strokeBorder(backgroundColor, lineWidth: ringThickness) // 2pt
    .frame(width: baseWidth, height: baseHeight)
    .allowsHitTesting(false)
```

### Edge Stroke Overlay (Layer 1a)

A 1pt hairline stroke for crisp definition:

```swift
.overlay(
    Capsule().strokeBorder(strokeColor, lineWidth: 1)
)
```

Where `strokeColor` is:
- Dark: `Color.white.opacity(0.12)`
- Light: `Color.black.opacity(0.12)`

---

## Glass Blur Layer

This is the core of the liquid glass effect. On macOS 15+, it uses SwiftUI's `.ultraThinMaterial`:

```swift
// Layer 2: Live blur
.background(
    Capsule().fill(.ultraThinMaterial)
)
```

`.ultraThinMaterial` creates a live, real-time frosted-glass blur of whatever is behind the window. The capsule shape clips the material to the pill form.

> [!NOTE]
> This is applied as a `.background()` on the content group, which means it sits **behind** the foreground elements (logo, visualizer bars) but **in front of** the transparent window.

### Why `.ultraThinMaterial` specifically?

| Material | Blur Intensity | Use Case |
|----------|---------------|----------|
| `.ultraThinMaterial` | Very subtle | ✅ Our choice — lets the background show through clearly with a light frosted tint |
| `.thinMaterial` | Light | More obscuring, harder to see background |
| `.regularMaterial` | Medium | Standard macOS sidebar-like blur |
| `.thickMaterial` | Heavy | Almost opaque |

We chose `.ultraThinMaterial` because the bar is small and should feel transparent/airy, not like a heavy overlay.

---

## Tint Overlay Layer

When the user selects the **"tinted" glass style**, a colored overlay is applied using the system accent color:

```swift
// Layer 3: Accent color tint (only when glassStyle == "tinted")
.background(
    Capsule().fill(Color.accentColor.opacity(tintOpacity))
)
```

The tint opacity values:

```swift
let isTintedStyle = (prefs.glassStyle == "tinted")
let tintOpacity: CGFloat = isTintedStyle ? (isDark ? 0.20 : 0.16) : 0.0
```

| Condition | Opacity |
|-----------|---------|
| Tinted + Dark mode | `0.20` (slightly more visible to stand out against dark backgrounds) |
| Tinted + Light mode | `0.16` (subtler to avoid looking "painted on") |
| Clear style | `0.0` (completely transparent — no tint) |

This overlay is placed **in front of** the blur material but **behind** the foreground content, so it tints the glass without coloring the text/icons.

---

## Inner Edge Stroke

A very thin stroke on the **glass capsule** (not the outer ring) to add depth:

```swift
.overlay(
    Capsule().strokeBorder(
        (isDark ? Color.white.opacity(0.22) : Color.black.opacity(0.18)),
        lineWidth: 0.9
    )
    .blendMode(isDark ? .screen : .multiply)
)
```

This creates a subtle inner border that makes the glass feel like it has physical edges. The blend mode logic is the same as the outer ring gradient.

---

## Foreground Content Layer

The actual visible UI sits on top of all glass layers:

```swift
HStack(spacing: 12) {
    LogoView(foregroundColor: foregroundColor)
        .frame(width: 19)
        .opacity(isShowingLogo ? 1 : 0)

    if isExpanded {
        HStack(spacing: 3) {
            ForEach(0..<7) { i in
                VisualizerBar(level: normalizedLevel, index: i, foregroundColor: foregroundColor)
            }
        }
        .transition(.scale(scale: 0.5, anchor: .leading).combined(with: .opacity))
    }
}
.padding(.horizontal, isExpanded ? 16 : 0)
```

### LogoView
A custom Whispr logo built from `RoundedRectangle` and `Circle` shapes. It uses the adaptive `foregroundColor` (white in dark mode, black in light mode).

### VisualizerBar
Seven animated bars that respond to the microphone's `audioLevel`. Each bar is phase-offset using a sine wave to create a natural ripple effect:

```swift
let barPhase = CGFloat(time) * 8 - CGFloat(index) * 0.7
let wave = (sin(barPhase) * 0.3 + 0.7)
let baseHeight: CGFloat = 4
let audioHeight = level * 18
let finalHeight = max(baseHeight, audioHeight * wave)
```

The `normalizedLevel` amplifies the raw audio level by 60× and clamps it:

```swift
private var normalizedLevel: CGFloat {
    let level = CGFloat(audioManager.audioLevel)
    return min(max(level * 60, 0.05), 1.0)
}
```

---

## AppKitGlassHost Fallback

The `AppKitGlassHost` struct is an `NSViewRepresentable` that wraps `NSVisualEffectView` for cases where the pure SwiftUI material approach doesn't produce reliable results. It is currently **not actively used** in the main rendering path (the SwiftUI `.ultraThinMaterial` approach is preferred), but remains in the codebase as a proven fallback.

### How it works

```swift
struct AppKitGlassHost: NSViewRepresentable {
    let content: AnyView
    let cornerRadius: CGFloat
    let tint: Color?
    let overlayOpacity: CGFloat
    let overlayColor: Color
    // ...
}
```

**Layer structure inside `makeNSView`:**

```
NSView (container — non-layer-backed)
└── NSVisualEffectView
    ├── material: .underWindowBackground
    ├── blendingMode: .behindWindow
    ├── state: .active
    ├── CALayer (tintLayer — colored overlay)
    └── NSHostingView (SwiftUI content on top)
```

Key details:

```swift
// Visual effect view for dependable live blur
let effectView = NSVisualEffectView(frame: .zero)
effectView.material = .underWindowBackground
effectView.blendingMode = .behindWindow
effectView.state = .active
effectView.wantsLayer = true
effectView.layer?.cornerRadius = cornerRadius
effectView.layer?.masksToBounds = true
```

> [!CAUTION]
> The container `NSView` must remain **non-layer-backed** (do NOT set `wantsLayer = true` on it). Setting the container to layer-backed breaks the live blur because macOS can no longer composite the behind-window content correctly.

### Tint via CALayer

Instead of a SwiftUI overlay, the tint is applied as a `CALayer` sublayer on the effect view:

```swift
let tintLayer = CALayer()
tintLayer.backgroundColor = NSColor(overlayColor).cgColor
tintLayer.opacity = Float(overlayOpacity)
tintLayer.cornerRadius = cornerRadius
tintLayer.masksToBounds = true
tintLayer.frame = effectView.bounds
tintLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
effectView.layer?.addSublayer(tintLayer)
```

### When to use AppKitGlassHost

Use this fallback if:
- `.ultraThinMaterial` stops working due to a macOS update
- The blur appears frozen or black
- You need more control over the blur material (e.g., different `NSVisualEffectView.Material` values)

To activate it, replace the SwiftUI material block with:

```swift
AppKitGlassHost(
    content: content,
    cornerRadius: glassHeight / 2,  // capsule radius
    tint: glassTint,
    overlayOpacity: tintOpacity,
    overlayColor: Color.accentColor
)
.frame(width: glassWidth, height: glassHeight)
.clipShape(Capsule())
```

---

## Color Scheme Adaptation

All colors adapt to light/dark mode using these computed values:

```swift
let isDark = (colorScheme == .dark)
let backgroundColor: Color = isDark ? .black : .white
let foregroundColor: Color = isDark ? .white : .black
let strokeColor: Color = isDark ? Color.white.opacity(0.12) : Color.black.opacity(0.12)
```

| Element | Dark Mode | Light Mode |
|---------|-----------|------------|
| Ring fill | Black | White |
| Text/icons | White | Black |
| Ring stroke | White @ 12% | Black @ 12% |
| Inner edge | White @ 22% | Black @ 18% |
| Inner edge blend mode | `.screen` | `.multiply` |

---

## Glass Style Preference

Stored in `PreferencesManager` as `glassStyle`:

```swift
@Published var glassStyle: String {
    didSet { UserDefaults.standard.set(glassStyle, forKey: Keys.glassStyle) }
}
// Default: "clear"
```

### Available styles

| Style | Value | Effect |
|-------|-------|--------|
| Clear | `"clear"` | Pure glass — no color tint, just blur + strokes |
| Tinted | `"tinted"` | Adds `Color.accentColor` overlay at 16–20% opacity |

The tint transition is animated:

```swift
.animation(.spring(response: 0.45, dampingFraction: 0.85), value: isTintedStyle)
```

---

## Sizing & Geometry

The bar has three states with different widths:

```swift
let baseWidth: CGFloat = isExpanded ? 160 : (isShowingLogo || isVanishing ? 44 : 0)
let baseHeight: CGFloat = 44
let ringThickness: CGFloat = 2
let glassWidth: CGFloat = max(baseWidth - ringThickness * 2, 0)   // 156 or 40 or 0
let glassHeight: CGFloat = max(baseHeight - ringThickness * 2, 0) // 40
```

| State | `baseWidth` | `glassWidth` | Description |
|-------|-------------|--------------|-------------|
| Hidden | `0` | `0` | Bar is not visible |
| Logo only | `44` | `40` | Small pill showing just the Whispr logo |
| Expanded | `160` | `156` | Full bar with logo + 7 visualizer bars |

The glass inset (`glassWidth/glassHeight`) is 2pt smaller on each side than the outer ring, creating a visible gap between the ring border and the glass fill.

---

## Animations

### Appear (Start Recording)

```swift
func startAnimationSequence() {
    isVanishing = false
    isShowingLogo = false
    isExpanded = false

    withAnimation(.spring(response: 0.4, dampingFraction: 0.8, blendDuration: 0)) {
        isShowingLogo = true  // Pill appears at 44pt with logo
    }
}
```

### Expand (Audio Detected)

Triggered when `audioLevel > expansionThreshold` (0.015):

```swift
.onChange(of: audioManager.audioLevel) { old, newValue in
    if isShowingLogo && !isExpanded && newValue > expansionThreshold {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)) {
            isExpanded = true  // Pill grows from 44pt → 160pt, visualizer bars appear
        }
    }
}
```

### Disappear (Stop Recording)

Three-phase animation:

```swift
func stopAnimationSequence() {
    // Phase 1: Shrink back to logo pill (160pt → 44pt)
    withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) {
        isExpanded = false
    }

    // Phase 2: Hold logo for 1.0 second
    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        isVanishing = true   // Lock frame at 44pt during fade

        // Phase 3: Fade + scale out
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            isShowingLogo = false
        }

        // Cleanup
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isVanishing = false
        }
    }
}
```

The `isVanishing` flag prevents the width from snapping to `0` immediately — it keeps the pill at `44pt` while the opacity and scale animate out, avoiding a jarring visual glitch.

### Global opacity & scale

Applied to the entire `ZStack`:

```swift
.opacity(isShowingLogo ? 1 : 0)
.scaleEffect(isShowingLogo ? 1.0 : 0.8)
```

This creates a unified "pop in/out" effect instead of individual elements appearing separately.

---

## Common Pitfalls & Fixes

### 1. Blur shows black/frozen background

**Cause:** Window is not truly transparent.  
**Fix:** Ensure all of these are set on `RecordingWindow`:
```swift
self.backgroundColor = .clear
self.isOpaque = false
self.hasShadow = false
// And on the hosting view:
hostingView.layer?.backgroundColor = .clear
```

### 2. Shadow appears around the bar

**Cause:** macOS adds default panel shadow.  
**Fix:** Set `hasShadow = false` on the window AND `shadowOpacity = 0` on the hosting view's layer.

### 3. Content (logo/bars) hidden behind glass

**Cause:** Glass effect applied as an overlay ON TOP of content.  
**Fix:** The glass (material + tint) must be applied as `.background()` modifiers on the content group, not as `.overlay()`. See the commented-out code block in the source:
```swift
/*
Removed glass effect overlay here as glass effect is moved behind foreground:
.overlay(
    Capsule()
        .fill(Color.clear)
        .glassEffect(.regular.tint(Color.white.opacity(0.18)).interactive())
)
*/
```

### 4. Container set to layer-backed breaks blur

**Cause:** In `AppKitGlassHost`, setting `wantsLayer = true` on the container `NSView` prevents `behindWindow` blending from working.  
**Fix:** Only the `NSVisualEffectView` should be layer-backed, not its container.

### 5. Bar flickers during resize

**Cause:** Width snapping to `0` before opacity animation completes.  
**Fix:** The `isVanishing` state flag keeps the width at `44pt` during the fade-out animation:
```swift
let baseWidth: CGFloat = isExpanded ? 160 : (isShowingLogo || isVanishing ? 44 : 0)
```

### 6. Tint color doesn't update

**Cause:** `glassStyle` preference not observed reactively.  
**Fix:** `PreferencesManager` is an `@StateObject` using `@Published` properties. Ensure you access it via `@StateObject private var prefs = PreferencesManager.shared` (not a plain property).

---

## Quick Reference: Rebuilding from Scratch

If you need to recreate the glass effect from zero, follow this order:

1. **Window**: Create an `NSPanel` with `backgroundColor: .clear`, `hasShadow: false`, `isOpaque: false`
2. **Outer ring**: `Capsule().strokeBorder()` — solid color, leaves center transparent
3. **Edge stroke on ring**: 1pt `strokeBorder` at 12% opacity
4. **Content group**: Your foreground elements (`HStack`, logo, visualizer)
5. **Behind content — tint**: `.background(Capsule().fill(Color.accentColor.opacity(...)))`
6. **Behind content — blur**: `.background(Capsule().fill(.ultraThinMaterial))`
7. **On content — inner stroke**: `.overlay(Capsule().strokeBorder(...))` at 0.9pt
8. **Wrap in ZStack**: Ring at back, content group at front
9. **Add opacity/scale**: `.opacity(isVisible ? 1 : 0).scaleEffect(isVisible ? 1 : 0.8)`

