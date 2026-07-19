# Onboarding Flow - Visual Reference

This document maps the implementation to the reference images provided.

## 📱 Screen Breakdown

### Screen 1: Welcome to Lyvo
**Reference:** `/mnt/data/1.png`

```
┌─────────────────────────────────────┐
│  9:41              [signal] [wifi]  │  ← Status bar (safe area)
│                                     │
│                            Skip  →  │  ← Skip button (top-right)
│                                     │
│                                     │
│         ┌─────────────────┐        │
│         │                 │        │
│         │                 │        │
│         │    🏢 (white)   │        │  ← Blue gradient card
│         │                 │        │     with apartment icon
│         │                 │        │
│         └─────────────────┘        │
│                                     │
│      Welcome to Lyvo                │  ← Title (34px, bold italic)
│                                     │
│  Manage your apartment community    │  ← Subtitle (15px, regular)
│  with ease. Everything you need     │     Two lines, centered
│  in one place.                      │
│                                     │
│                                     │
│          ● ○ ○ ○                   │  ← Page indicators
│                                     │
│  ┌─────────────────────────────┐  │
│  │         Next                 │  │  ← CTA button (56px height)
│  └─────────────────────────────┘  │     Blue gradient
│                                     │
└─────────────────────────────────────┘
```

**Key Elements:**
- Card: 254px × 254px (65% of 390px width)
- Icon: Apartment/building (white, ~100px)
- Gradient: #2563EB → #1E40AF (top to bottom)
- Shadow: Soft, 24px blur, 8px offset
- Border radius: 20px

---

### Screen 2: Visitor Management
**Reference:** `/mnt/data/2.png`

```
┌─────────────────────────────────────┐
│  9:41              [signal] [wifi]  │
│                                     │
│                            Skip  →  │
│                                     │
│                                     │
│         ┌─────────────────┐        │
│         │                 │        │
│         │                 │        │
│         │   👥 (white)    │        │  ← Blue gradient card
│         │                 │        │     with people icon
│         │                 │        │
│         └─────────────────┘        │
│                                     │
│    Visitor Management               │  ← Title
│                                     │
│  Pre-approve visitors, track        │  ← Subtitle
│  deliveries, and manage entry       │
│  passes seamlessly.                 │
│                                     │
│                                     │
│          ○ ● ○ ○                   │  ← Page 2 active
│                                     │
│  ┌─────────────────────────────┐  │
│  │         Next                 │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

**Key Elements:**
- Same card styling as Screen 1
- Icon: People/visitors (white)
- Active dot: Second position
- Button: Still says "Next"

---

### Screen 3: Stay Updated
**Reference:** `/mnt/data/3.png`

```
┌─────────────────────────────────────┐
│  9:41              [signal] [wifi]  │
│                                     │
│                            Skip  →  │
│                                     │
│                                     │
│         ┌─────────────────┐        │
│         │                 │        │
│         │                 │        │
│         │    🔔 (white)   │        │  ← Blue gradient card
│         │                 │        │     with bell icon
│         │                 │        │
│         └─────────────────┘        │
│                                     │
│       Stay Updated                  │  ← Title
│                                     │
│  Get real-time notifications for    │  ← Subtitle
│  bills, events, announcements,      │
│  and more.                          │
│                                     │
│                                     │
│          ○ ○ ● ○                   │  ← Page 3 active
│                                     │
│  ┌─────────────────────────────┐  │
│  │         Next                 │  │
│  └─────────────────────────────┘  │
│                                     │
└─────────────────────────────────────┘
```

**Key Elements:**
- Same card styling
- Icon: Notification bell (white)
- Active dot: Third position
- Button: Still says "Next"

---

### Screen 4: Safe & Secure
**Reference:** `/mnt/data/4.png`

```
┌─────────────────────────────────────┐
│  9:41              [signal] [wifi]  │
│                                     │
│                            Skip  →  │
│                                     │
│                                     │
│         ┌─────────────────┐        │
│         │                 │        │
│         │                 │        │
│         │    🛡️ (white)   │        │  ← Blue gradient card
│         │                 │        │     with shield icon
│         │                 │        │
│         └─────────────────┘        │
│                                     │
│      Safe & Secure                  │  ← Title
│                                     │
│  Your data is protected with        │  ← Subtitle
│  enterprise-grade security.         │
│  Privacy guaranteed.                │
│                                     │
│                                     │
│          ○ ○ ○ ●                   │  ← Page 4 active (last)
│                                     │
│  ┌─────────────────────────────┐  │
│  │      Get Started             │  │  ← Final CTA
│  └─────────────────────────────┘  │     (different text)
│                                     │
└─────────────────────────────────────┘
```

**Key Elements:**
- Same card styling
- Icon: Shield/security (white)
- Active dot: Fourth position (last)
- Button: Says "Get Started" (final screen)

---

## 🎨 Design System

### Colors (Exact Values)

```dart
Primary Blue:        #2563EB  (rgb: 37, 99, 235)
Primary Blue Dark:   #1E40AF  (rgb: 30, 64, 175)
Background:          #F7F7F7  (rgb: 247, 247, 247)
Text Primary:        #111111  (rgb: 17, 17, 17)
Text Secondary:      #666666  (rgb: 102, 102, 102)
White:               #FFFFFF  (rgb: 255, 255, 255)
```

### Typography

```
Title:
  - Font size: 34px
  - Weight: Bold (700)
  - Style: Italic
  - Color: #111111
  - Letter spacing: -0.5px
  - Line height: 1.2

Subtitle:
  - Font size: 15px
  - Weight: Regular (400)
  - Color: #666666
  - Letter spacing: 0
  - Line height: 1.5

Button Text:
  - Font size: 18px
  - Weight: Semibold (600)
  - Color: #FFFFFF
  - Letter spacing: 0.2px

Skip Text:
  - Font size: 16px
  - Weight: Medium (500)
  - Color: #111111
```

### Spacing & Sizing

```
Screen Width (iPhone 13):  390px
Card Size:                 254px × 254px (65% of width)
Card Border Radius:        20px
Icon Size:                 ~100px (40% of card)
Button Height:             56px
Button Border Radius:      12px
Horizontal Padding:        16px
Top Spacing (Skip):        8px
Card to Title Gap:         40px
Title to Subtitle Gap:     16px
Indicators to Button:      24px
Button to Bottom:          24px
```

### Shadows

```
Card Shadow:
  - Color: #2563EB at 25% opacity
  - Blur: 24px
  - Offset: 0px, 8px
  - Spread: 0px
  
  Secondary Shadow:
  - Color: #2563EB at 10% opacity
  - Blur: 48px
  - Offset: 0px, 16px
  - Spread: 0px

Button Shadow:
  - Color: #2563EB at 30% opacity
  - Blur: 12px
  - Offset: 0px, 4px
  - Spread: 0px
```

### Gradients

```
Primary Gradient (Card & Button):
  - Type: Linear
  - Direction: Top to Bottom (180°)
  - Start: #2563EB (0%)
  - End: #1E40AF (100%)
```

---

## 🎬 Animation Specifications

### Card Entrance (600ms)
```
Initial State:
  - Opacity: 0
  - Scale: 0.8

Final State:
  - Opacity: 1.0
  - Scale: 1.0

Curve: easeOutBack
Timing: 600ms
```

### Page Transition (350ms)
```
Exit Animation:
  - Slide: Left (-100%)
  - Opacity: 1.0 → 0.0

Enter Animation:
  - Slide: Right (100%) → Center (0%)
  - Opacity: 0.0 → 1.0

Curve: easeOutCubic
Timing: 350ms
```

### Button Press (200ms)
```
Press:
  - Scale: 1.0 → 0.95

Release:
  - Scale: 0.95 → 1.0

Curve: easeOut
Timing: 200ms
```

### Page Indicators (300ms)
```
Active Dot:
  - Width: 8px → 24px
  - Opacity: 0.3 → 1.0

Inactive Dot:
  - Width: 24px → 8px
  - Opacity: 1.0 → 0.3

Curve: easeInOut
Timing: 300ms
```

### Background Wave (2000ms loop)
```
Wave Motion:
  - Amplitude: 20px
  - Frequency: 2 waves per screen width
  - Speed: 2000ms per cycle
  - Opacity: 0.02 (very subtle)

Curve: linear (continuous loop)
```

---

## 📐 Layout Measurements (iPhone 13)

```
Device Dimensions:
  Width: 390px
  Height: 844px
  Safe Area Top: ~47px (status bar)
  Safe Area Bottom: ~34px (home indicator)

Content Layout:
  Skip Button:
    - Position: Top-right
    - Padding: 16px from right, 8px from top
    - Size: 44px × 44px (touch target)

  Card:
    - Width: 254px (65% of 390px)
    - Height: 254px (square)
    - Position: Centered horizontally
    - Vertical: ~25% from top

  Title:
    - Position: 40px below card
    - Max width: 358px (390 - 32px padding)

  Subtitle:
    - Position: 16px below title
    - Max width: 358px

  Page Indicators:
    - Position: 24px above button
    - Centered horizontally

  Button:
    - Width: 358px (full width - 32px padding)
    - Height: 56px
    - Position: 24px from bottom safe area
```

---

## 🔄 Interaction States

### Skip Button
```
Normal:   Color: #111111, Opacity: 1.0
Pressed:  Color: #111111, Opacity: 0.6
```

### Next/Get Started Button
```
Normal:   Gradient, Shadow visible
Pressed:  Scale: 0.95, Shadow slightly reduced
Disabled: Opacity: 0.5 (not used in this flow)
```

### Page Indicators
```
Active:   Width: 24px, Color: #2563EB, Opacity: 1.0
Inactive: Width: 8px, Color: #2563EB, Opacity: 0.3
```

---

## 📱 Responsive Behavior

### Small Screens (< 375px width)
- Card scales to 60% of width
- Font sizes reduce by 10%
- Spacing reduces proportionally

### Large Screens (> 414px width)
- Card maintains max size of 280px
- Content remains centered
- Extra space distributed evenly

### Tablets/iPads
- Card size caps at 320px
- Increased horizontal padding (24px)
- Content remains vertically centered

---

## ✅ Implementation Checklist

Use this to verify your implementation matches the reference:

- [ ] Card gradient matches exactly (#2563EB → #1E40AF)
- [ ] Card size is 65% of screen width
- [ ] Icons are white and centered
- [ ] Title is bold italic, 34px
- [ ] Subtitle is regular, 15px, two lines
- [ ] Skip button in top-right corner
- [ ] Page indicators show correct active state
- [ ] Button says "Next" on screens 1-3
- [ ] Button says "Get Started" on screen 4
- [ ] All spacing matches measurements
- [ ] Shadows are soft and subtle
- [ ] Animations are smooth (60fps)
- [ ] Safe area prevents status bar overlap

---

## 🎯 Pixel-Perfect Matching Tips

1. **Use the exact color values** - Don't approximate
2. **Measure spacing with precision** - Use the values provided
3. **Test on iPhone 13 simulator** - Primary target device
4. **Compare side-by-side** - Reference images vs implementation
5. **Check font weights** - Bold italic for title is critical
6. **Verify shadow softness** - Should be subtle, not harsh
7. **Test animations** - Should feel smooth and natural
8. **Validate touch targets** - Minimum 44px for accessibility

---

**Reference Images Location:**
- `/mnt/data/1.png` - Welcome to Lyvo
- `/mnt/data/2.png` - Visitor Management
- `/mnt/data/3.png` - Stay Updated
- `/mnt/data/4.png` - Safe & Secure

**Implementation Files:**
- `lib/src/screens/onboarding_flow.dart` - Main flow
- `lib/src/widgets/animated_onboarding_card.dart` - Card component
- `lib/src/constants/onboarding_styles.dart` - Design tokens
