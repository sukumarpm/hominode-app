# AppSegmentedControl - Visual Design Guide

## Component Anatomy

```
┌─────────────────────────────────────────────────────────┐
│  ← 20px margin                        20px margin →     │
│  ┌───────────────────────────────────────────────────┐  │
│  │ Track Background (#F0F1F3) - 48px height         │  │
│  │ ┌─ 4px padding ─────────────────────────────┐    │  │
│  │ │                                            │    │  │
│  │ │  ┌──────────────┐  ┌──────────┐  ┌──────┐│    │  │
│  │ │  │ Active Pill  │  │ Inactive │  │ Inact││    │  │
│  │ │  │   (White)    │  │  Text    │  │ Text ││    │  │
│  │ │  │   + Shadow   │  │          │  │      ││    │  │
│  │ │  └──────────────┘  └──────────┘  └──────┘│    │  │
│  │ │                                            │    │  │
│  │ └────────────────────────────────────────────┘    │  │
│  └───────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────┘
     ↑                                                ↑
  30px radius                                    30px radius
```

## State Variations

### 2 Segments - Messages Screen

#### State 1: "Chats" Selected
```
┌─────────────────────────────────────────┐
│  ┌─────────────────┐  ┌──────────────┐ │
│  │     Chats       │  │Notifications │ │
│  │   (Bold #0F)    │  │ (Med #9AA0)  │ │
│  │  [White Pill]   │  │              │ │
│  └─────────────────┘  └──────────────┘ │
└─────────────────────────────────────────┘
```

#### State 2: "Notifications" Selected
```
┌─────────────────────────────────────────┐
│  ┌──────────────┐  ┌─────────────────┐ │
│  │    Chats     │  │ Notifications   │ │
│  │ (Med #9AA0)  │  │  (Bold #0F)     │ │
│  │              │  │ [White Pill]    │ │
│  └──────────────┘  └─────────────────┘ │
└─────────────────────────────────────────┘
```

### 3 Segments - Events Screen

```
┌──────────────────────────────────────────────────┐
│  ┌──────────┐  ┌──────────┐  ┌──────────┐       │
│  │  Events  │  │ Notices  │  │  Polls   │       │
│  │(Bold #0F)│  │(Med #9AA)│  │(Med #9AA)│       │
│  │[White]   │  │          │  │          │       │
│  └──────────┘  └──────────┘  └──────────┘       │
└──────────────────────────────────────────────────┘
```

### 4 Segments - Marketplace Screen

```
┌─────────────────────────────────────────────────────────┐
│  ┌────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐ │
│  │  All   │  │Furniture │  │Electronics│ │  Other   │ │
│  │(Bold)  │  │ (Medium) │  │ (Medium)  │ │ (Medium) │ │
│  │[White] │  │          │  │           │ │          │ │
│  └────────┘  └──────────┘  └──────────┘  └──────────┘ │
└─────────────────────────────────────────────────────────┘
```

## Animation Sequence

### Sliding from Segment 0 → Segment 2

```
Frame 0ms (Start):
┌────────────────────────────────────────┐
│ [Pill]     Segment 1     Segment 2    │
└────────────────────────────────────────┘

Frame 55ms (25%):
┌────────────────────────────────────────┐
│ Segment 0  [Pill]       Segment 2     │
└────────────────────────────────────────┘

Frame 110ms (50%):
┌────────────────────────────────────────┐
│ Segment 0  Segment 1    [Pill]        │
└────────────────────────────────────────┘

Frame 165ms (75%):
┌────────────────────────────────────────┐
│ Segment 0  Segment 1    [Pill]        │
└────────────────────────────────────────┘

Frame 220ms (Complete):
┌────────────────────────────────────────┐
│ Segment 0  Segment 1    [Pill]        │
└────────────────────────────────────────┘
```

## Color Palette

### Primary Colors
```
┌──────────────┬──────────────┬──────────────┐
│   Track      │  Active Pill │ Active Text  │
│   #F0F1F3    │   #FFFFFF    │   #0F172A    │
│ ░░░░░░░░░░░░ │ ████████████ │ ████████████ │
└──────────────┴──────────────┴──────────────┘

┌──────────────┬──────────────┬──────────────┐
│Inactive Text │    Shadow    │   Border     │
│   #9AA0A6    │rgba(16,24,40)│     None     │
│ ▒▒▒▒▒▒▒▒▒▒▒▒ │   .12 alpha  │              │
└──────────────┴──────────────┴──────────────┘
```

## Typography Scale

### Active State
```
Font Size: 15px
Weight: 700 (Bold)
Color: #0F172A
Letter Spacing: -0.2px

Example: "Events"
```

### Inactive State
```
Font Size: 15px
Weight: 500 (Medium)
Color: #9AA0A6
Letter Spacing: -0.2px

Example: "Events"
```

## Shadow Visualization

### Active Pill Shadow
```
Vertical View:
     ┌─────────────┐
     │ White Pill  │ ← 0px offset
     └─────────────┘
          ▓▓▓▓▓      ← 3px offset
         ▓▓▓▓▓▓▓     ← 12px blur
        ▓▓▓▓▓▓▓▓▓    ← rgba(16,24,40,0.12)
```

## Spacing System

### Internal Spacing
```
┌─ Container ──────────────────────────────┐
│ ← 4px padding                            │
│  ┌─ Pill ─────────────────────────────┐  │
│  │ ← 12px → Text ← 12px →             │  │
│  └────────────────────────────────────┘  │
│                            4px padding → │
└──────────────────────────────────────────┘
```

### External Spacing
```
Screen Edge
│
├─ 20px margin →
│                ┌─ Segmented Control ─┐
│                │                      │
│                └──────────────────────┘
│                ← 20px margin ─
│
Screen Edge
```

## Responsive Behavior

### iPhone SE (375px width)
```
Control Width: 335px (375 - 40)
2 Segments: 167.5px each
3 Segments: 111.67px each
4 Segments: 83.75px each
```

### iPhone 13 (390px width)
```
Control Width: 350px (390 - 40)
2 Segments: 175px each
3 Segments: 116.67px each
4 Segments: 87.5px each
```

### iPhone 13 Pro Max (428px width)
```
Control Width: 388px (428 - 40)
2 Segments: 194px each
3 Segments: 129.33px each
4 Segments: 97px each
```

## Comparison: Old vs New

### Old SegmentedControl
```
┌─────────────────────────────────────────┐
│ Background: #F5F5F5                     │
│ Radius: 24px                            │
│ Shadow: Basic (0.05 alpha)              │
│ Animation: 200ms                        │
│ Active Weight: 600                      │
│ ┌──────────┐  ┌──────────┐             │
│ │  Active  │  │ Inactive │             │
│ └──────────┘  └──────────┘             │
└─────────────────────────────────────────┘
```

### New AppSegmentedControl
```
┌─────────────────────────────────────────┐
│ Background: #F0F1F3                     │
│ Radius: 30px (more pill-like)           │
│ Shadow: Premium (0.12 alpha, 12px blur) │
│ Animation: 220ms (smoother)             │
│ Active Weight: 700 (bolder)             │
│ ┌──────────┐  ┌──────────┐             │
│ │  Active  │  │ Inactive │             │
│ └──────────┘  └──────────┘             │
└─────────────────────────────────────────┘
```

## Real-World Examples

### Messages Screen Layout
```
┌─────────────────────────────────────────┐
│  Messages                         🔔    │ ← Header
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ [Chats]    Notifications        │   │ ← Segmented Control
│  └─────────────────────────────────┘   │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │ 👤 John Doe                     │   │
│  │    Hey, how are you?            │   │ ← Chat List
│  └─────────────────────────────────┘   │
│  ┌─────────────────────────────────┐   │
│  │ 👤 Jane Smith                   │   │
│  │    See you tomorrow!            │   │
│  └─────────────────────────────────┘   │
└─────────────────────────────────────────┘
```

### Marketplace Screen Layout
```
┌─────────────────────────────────────────┐
│  Marketplace                      🔍    │ ← Header
├─────────────────────────────────────────┤
│                                         │
│  ┌─────────────────────────────────┐   │
│  │[All] Furniture Electronics Other│   │ ← Segmented Control
│  └─────────────────────────────────┘   │
│                                         │
│  ┌──────────┐  ┌──────────┐           │
│  │  Item 1  │  │  Item 2  │           │ ← Product Grid
│  │  $50     │  │  $75     │           │
│  └──────────┘  └──────────┘           │
│  ┌──────────┐  ┌──────────┐           │
│  │  Item 3  │  │  Item 4  │           │
│  │  $100    │  │  $25     │           │
│  └──────────┘  └──────────┘           │
└─────────────────────────────────────────┘
```

## Accessibility Features

### High Contrast Mode
```
Normal:
┌─────────────────────────────────────────┐
│  [Active: #0F172A]  Inactive: #9AA0A6  │
└─────────────────────────────────────────┘

High Contrast:
┌─────────────────────────────────────────┐
│  [Active: #000000]  Inactive: #666666  │
└─────────────────────────────────────────┘
```

### Focus States (Web/Desktop)
```
Keyboard Focus:
┌─────────────────────────────────────────┐
│  ┏━━━━━━━━━━┓  ┌──────────┐            │
│  ┃  Active  ┃  │ Inactive │            │
│  ┗━━━━━━━━━━┛  └──────────┘            │
└─────────────────────────────────────────┘
     ↑ 2px blue outline
```

## Print/Export Specifications

### Design Handoff
```
Component: AppSegmentedControl
Figma/Sketch: Export at 1x, 2x, 3x
Colors: Use exact hex values
Fonts: SF Pro (iOS), Roboto (Android)
Spacing: Use 4px grid system
```

### Developer Handoff
```
Widget: AppSegmentedControl
File: lib/src/components/app_segmented_control.dart
Props: segments, selectedIndex, onChanged
Docs: APP_SEGMENTED_CONTROL_README.md
Demo: lib/app_segmented_control_demo.dart
```

## Quality Checklist

Visual Design:
- [x] Pill shape (30px radius)
- [x] Premium shadow
- [x] Smooth animation
- [x] Clear active state
- [x] Proper spacing

Interaction:
- [x] Tap to switch
- [x] Smooth sliding
- [x] No jank
- [x] Proper feedback
- [x] Touch targets

Accessibility:
- [x] High contrast
- [x] Screen reader support
- [x] Keyboard navigation
- [x] Focus indicators
- [x] WCAG AA compliant

Performance:
- [x] 60 FPS animation
- [x] No memory leaks
- [x] Fast initial render
- [x] Efficient rebuilds
- [x] Small bundle size
