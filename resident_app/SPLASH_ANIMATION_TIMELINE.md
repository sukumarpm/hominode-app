# Splash Screen Animation Timeline

## Visual Timeline (2200ms)

```
0ms                                                                    2200ms
|----------------------------------------------------------------------|
│                                                                      │
│  LOGO ENTRY          SHADOW      SQUASH   TAGLINE      HOLD    TRANS│
│  (0-600ms)          (350-900ms)  (600ms)  (850-1250ms) (1250-  (1900│
│                                                         1900ms) 2200)│
│                                                                      │
└──────────────────────────────────────────────────────────────────────┘
```

## Detailed Phase Breakdown

### Phase 1: Logo Entry (0ms - 600ms)
```
Animation: Logo appears with physics-based entrance
├─ Scale: 0.6 → 1.05 (slight overshoot)
├─ Opacity: 0 → 1
├─ Rotation: -3° → 0°
├─ Y Position: +20px → 0
└─ Curve: easeOutBack (bounce feel)

Visual Effect: Logo "pops" into view with subtle 3D rotation
```

### Phase 2: Shadow & Depth (350ms - 900ms)
```
Animation: Shadow grows and softens for depth
├─ Shadow Opacity: 0 → 0.35
├─ Shadow Blur: 8px → 24px
├─ Reflection Opacity: 0 → 0.12
└─ Curve: easeOut

Visual Effect: Logo gains depth and "lifts" off background
```

### Phase 3: Squash & Settle (600ms - 690ms)
```
Animation: Micro bounce for premium feel
├─ ScaleX: 1.0 → 1.08 → 1.0
├─ ScaleY: 1.0 → 0.94 → 1.0
├─ Duration: 90ms (very quick)
└─ Curve: linear (for precise control)

Visual Effect: Subtle "landing" bounce - barely noticeable but adds quality
```

### Phase 4: Tagline Entry (850ms - 1250ms)
```
Animation: Text fades up
├─ Opacity: 0 → 1 (with 0.9 final opacity)
├─ Y Position: +12px → 0
├─ Duration: 400ms
└─ Curve: easeOut

Visual Effect: "Your Community, Connected" smoothly appears below logo
```

### Phase 5: Hold (1250ms - 1900ms)
```
Animation: Static hold
├─ Duration: 650ms
└─ Purpose: Brand readability and recognition

Visual Effect: Everything stays still for user to read
```

### Phase 6: Transition (1900ms - 2200ms)
```
Animation: Fade out to home screen
├─ Opacity: 1 → 0
├─ Scale: 1.0 → 0.98 (subtle zoom out)
├─ Duration: 300ms
└─ Curve: easeInOut

Visual Effect: Smooth cross-fade to home screen
```

## Parallel Animations

### Particles (Optional, 600ms - 1600ms)
```
Animation: Floating particles in background
├─ Count: 4 particles
├─ Y Movement: 0 → -80px (upward drift)
├─ Opacity: 0 → 0.08 → 0 (fade in/out)
├─ Stagger: 150ms delay between each
└─ Status: Disabled by default (performance)

Visual Effect: Subtle ambient motion in background
```

## Animation Curves Explained

### easeOutBack
```
Used for: Logo entry
Effect: Overshoots target then settles back
Feel: Playful, energetic, modern
```

### easeOut
```
Used for: Shadow, tagline, particles
Effect: Fast start, slow end
Feel: Natural deceleration
```

### easeInOut
```
Used for: Transition
Effect: Smooth acceleration and deceleration
Feel: Polished, professional
```

### linear
```
Used for: Squash & stretch
Effect: Constant speed
Feel: Precise, mechanical (needed for micro-animation)
```

## Timing Rationale

| Phase | Duration | Why |
|-------|----------|-----|
| Logo Entry | 600ms | Long enough to feel smooth, short enough to stay snappy |
| Shadow | 550ms | Slightly shorter than logo for layered effect |
| Squash | 90ms | Very quick - should be barely noticeable |
| Tagline | 400ms | Quick read-in, doesn't slow down flow |
| Hold | 650ms | Enough time to read brand name + tagline |
| Transition | 300ms | Standard transition duration |
| **Total** | **2200ms** | **Under 3 seconds - modern standard** |

## Reduced Motion Timeline

When accessibility "Reduce Motion" is enabled:

```
0ms                                    2200ms
|----------------------------------------|
│                                        │
│  FADE IN        HOLD         FADE OUT │
│  (0-660ms)      (660-1870ms) (1870-   │
│                              2200ms)   │
│                                        │
└────────────────────────────────────────┘
```

Simplified:
- No scale, rotation, or translation
- Simple opacity fade: 0 → 1
- No bounce or particles
- Same total duration for consistency

## Performance Considerations

### GPU-Accelerated Properties
✅ Opacity
✅ Transform (scale, rotate, translate)
✅ Composited layers

### CPU-Heavy Properties (Avoided)
❌ Width/Height animations
❌ Layout changes
❌ Excessive blur (limited to shadow only)

### Optimization Techniques
1. **Composited transforms** - All animations use Transform widgets
2. **Minimal repaints** - AnimatedBuilder only rebuilds necessary parts
3. **Efficient curves** - Native Flutter curves (no custom interpolation)
4. **Optional particles** - Disabled by default, can enable for high-end devices
5. **Reduced motion** - Automatic fallback for accessibility

## Frame Budget

Target: **60 FPS** = 16.67ms per frame

Breakdown per frame:
- Transform calculations: ~1ms
- Opacity blending: ~2ms
- Shadow rendering: ~3ms
- Particle rendering (if enabled): ~2ms
- **Total: ~8ms** ✅ Well under budget

## Accessibility Timeline

### Standard Motion (Default)
- Full animation sequence
- All effects enabled
- 2200ms total

### Reduced Motion (Auto-detected)
- Simple fade only
- No bounces or rotations
- Same 2200ms (consistency)

### Slow Device Mode (Manual)
- Same as reduced motion
- Can be toggled for testing

## Synchronization Points

Key moments where animations align:

| Time | Event |
|------|-------|
| 0ms | Logo starts entering |
| 350ms | Shadow starts growing (logo at 58% complete) |
| 600ms | Logo reaches overshoot, squash begins |
| 690ms | Squash complete, logo settled |
| 850ms | Tagline starts (logo fully settled) |
| 1250ms | All motion stops, hold begins |
| 1900ms | Transition starts |
| 2200ms | Complete, navigate to home |

## Testing Checkpoints

Use these timestamps to verify animation quality:

- **300ms:** Logo should be ~50% scaled, rotating
- **600ms:** Logo should hit 1.05 scale (overshoot)
- **650ms:** Logo should be at 1.0 scale (settled)
- **900ms:** Shadow should be fully visible
- **1100ms:** Tagline should be fully visible
- **1900ms:** Everything should be static
- **2050ms:** Should be fading out

## Configuration Override

To adjust timing, modify `SplashConfig` class:

```dart
// Make it faster (1.5s)
static const int totalDuration = 1500;
static const int logoEntryDuration = 400;
static const int taglineDelay = 600;
static const int transitionDelay = 1200;

// Make it slower (3s)
static const int totalDuration = 3000;
static const int logoEntryDuration = 800;
static const int taglineDelay = 1200;
static const int transitionDelay = 2500;
```

## Animation Quality Checklist

- [ ] Logo entrance feels smooth and energetic
- [ ] Overshoot is subtle (not too bouncy)
- [ ] Shadow grows naturally
- [ ] Squash bounce is barely noticeable
- [ ] Tagline appears at right moment
- [ ] Hold duration allows reading
- [ ] Transition is smooth
- [ ] No jank or stuttering
- [ ] Runs at 60fps
- [ ] Reduced motion works correctly

---

**Total Duration:** 2200ms (2.2 seconds)
**Target FPS:** 60
**Animation Phases:** 6
**Parallel Animations:** 4 (logo, shadow, reflection, tagline)
**Optional Effects:** Particles (disabled by default)
