# Login Screen - Visual Implementation Guide

## Screen Breakdown

### Full Screen View
```
┌─────────────────────────────────────────┐
│ 9:41          [signal] [wifi] [battery] │ ← Status Bar (Light)
├─────────────────────────────────────────┤
│                                         │
│                                         │
│          [Gradient Background]          │
│            #2F80ED → #2563EB            │
│                                         │
│                                         │
│           Welcome Back                  │ ← 28pt Bold
│   Login to your SocietyConnect account  │ ← 16pt Regular
│                                         │
│                                         │
│  ╔═══════════════════════════════════╗ │
│  ║                                   ║ │
│  ║  Login                            ║ │ ← 22pt Semibold
│  ║                                   ║ │
│  ║  Mobile Number                    ║ │ ← 16pt Medium
│  ║  ┌─────────────────────────────┐ ║ │
│  ║  │ Enter your mobile number    │ ║ │ ← Input Field
│  ║  └─────────────────────────────┘ ║ │
│  ║                                   ║ │
│  ║  ┌─────────────────────────────┐ ║ │
│  ║  │       Send OTP              │ ║ │ ← Primary Button
│  ║  └─────────────────────────────┘ ║ │
│  ║                                   ║ │
│  ║  Don't have an account? Register ║ │ ← Link
│  ║                                   ║ │
│  ╚═══════════════════════════════════╝ │
│                                         │
│                                         │
└─────────────────────────────────────────┘
```

## Component Details

### 1. Background Gradient
```
┌─────────────────────────────────────────┐
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ ← #2F80ED (Top)
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ ← Gradient
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │
│ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓ │ ← #2563EB (Bottom)
└─────────────────────────────────────────┘

LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [Color(0xFF2F80ED), Color(0xFF2563EB)],
)
```

### 2. Welcome Text Section
```
        ┌─────────────────────────┐
        │                         │
        │    Welcome Back         │ ← 28pt, Bold, White
        │                         │ ← Letter spacing: -0.5
        └─────────────────────────┘
                  ↓ 12px
        ┌─────────────────────────┐
        │ Login to your           │ ← 16pt, Regular
        │ SocietyConnect account  │ ← Color: #F0F0F0
        └─────────────────────────┘
```

### 3. White Card Container
```
  ┌─────────────────────────────────────┐
  │ ╭─────────────────────────────────╮ │ ← 28px radius
  │ │                                 │ │
  │ │  28px padding ←→                │ │
  │ │                                 │ │
  │ │  ↕ 32px padding                 │ │
  │ │                                 │ │
  │ │  [Content]                      │ │
  │ │                                 │ │
  │ │  ↕ 32px padding                 │ │
  │ │                                 │ │
  │ ╰─────────────────────────────────╯ │
  └─────────────────────────────────────┘
  
  Background: #FFFFFF
  Shadow: rgba(0,0,0,0.08), blur: 20px, offset: (0,4)
```

### 4. Input Field
```
  ┌─────────────────────────────────────┐
  │ ╭─────────────────────────────────╮ │ ← 12px radius
  │ │ 16px ← Enter your mobile number │ │ ← 16px padding
  │ ╰─────────────────────────────────╯ │
  └─────────────────────────────────────┘
  
  Background: #F5F5F5
  Border: 1px solid #E5E7EB
  Text: 15pt, Regular, #111111
  Hint: 15pt, Regular, #A3A3A3
  Height: ~52px (auto with padding)
```

### 5. Primary Button
```
  ┌─────────────────────────────────────┐
  │ ╭─────────────────────────────────╮ │ ← 12px radius
  │ │                                 │ │
  │ │         Send OTP                │ │ ← 17pt, Semibold
  │ │                                 │ │ ← White text
  │ ╰─────────────────────────────────╯ │
  └─────────────────────────────────────┘
  
  Background: #2563EB
  Height: 54px
  Text: 17pt, Semibold, #FFFFFF
  No shadow, no border
```

### 6. Footer Link
```
  ┌─────────────────────────────────────┐
  │                                     │
  │  Don't have an account? Register    │
  │  ─────────────────────  ────────    │
  │  #111111 (Regular)      #2563EB     │
  │  15pt, Medium           15pt, Bold  │
  │                                     │
  └─────────────────────────────────────┘
```

## Spacing Diagram

### Vertical Spacing
```
┌─────────────────────────────────────┐
│ Status Bar                          │
├─────────────────────────────────────┤
│                                     │
│ ↕ 120px                             │
│                                     │
├─────────────────────────────────────┤
│ Welcome Back                        │
├─────────────────────────────────────┤
│ ↕ 12px                              │
├─────────────────────────────────────┤
│ Subtitle                            │
├─────────────────────────────────────┤
│                                     │
│ ↕ 48px                              │
│                                     │
├─────────────────────────────────────┤
│ ┌─────────────────────────────────┐ │
│ │ ↕ 32px (top padding)            │ │
│ ├─────────────────────────────────┤ │
│ │ Login                           │ │
│ ├─────────────────────────────────┤ │
│ │ ↕ 28px                          │ │
│ ├─────────────────────────────────┤ │
│ │ Mobile Number                   │ │
│ ├─────────────────────────────────┤ │
│ │ ↕ 10px                          │ │
│ ├─────────────────────────────────┤ │
│ │ Input Field                     │ │
│ ├─────────────────────────────────┤ │
│ │ ↕ 28px                          │ │
│ ├─────────────────────────────────┤ │
│ │ Button                          │ │
│ ├─────────────────────────────────┤ │
│ │ ↕ 20px                          │ │
│ ├─────────────────────────────────┤ │
│ │ Link                            │ │
│ ├─────────────────────────────────┤ │
│ │ ↕ 32px (bottom padding)         │ │
│ └─────────────────────────────────┘ │
├─────────────────────────────────────┤
│                                     │
│ ↕ 40px                              │
│                                     │
└─────────────────────────────────────┘
```

### Horizontal Spacing
```
┌─────────────────────────────────────┐
│ 20px                          20px  │
│  ↔  ┌─────────────────────┐  ↔     │
│     │ 28px          28px  │        │
│     │  ↔  [Content]  ↔    │        │
│     │                     │        │
│     └─────────────────────┘        │
└─────────────────────────────────────┘

Screen edges to card: 20px
Card internal padding: 28px
Input internal padding: 16px
```

## Color Palette Visual

### Primary Colors
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ #2F80ED  │  │ #2563EB  │  │ #FFFFFF  │
│ Gradient │  │ Primary  │  │  White   │
│   Top    │  │  Button  │  │   Card   │
└──────────┘  └──────────┘  └──────────┘
```

### Background Colors
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ #F5F5F5  │  │ #E5E7EB  │  │ #FFFFFF  │
│  Input   │  │  Border  │  │   Card   │
│   BG     │  │          │  │          │
└──────────┘  └──────────┘  └──────────┘
```

### Text Colors
```
┌──────────┐  ┌──────────┐  ┌──────────┐
│ #FFFFFF  │  │ #F0F0F0  │  │ #111111  │
│  Title   │  │ Subtitle │  │  Label   │
│  White   │  │  White   │  │  Black   │
└──────────┘  └──────────┘  └──────────┘

┌──────────┐  ┌──────────┐
│ #A3A3A3  │  │ #2563EB  │
│   Hint   │  │   Link   │
│   Grey   │  │   Blue   │
└──────────┘  └──────────┘
```

## Typography Scale

### Font Sizes
```
28pt ████████████████████████████ Welcome Back
22pt ██████████████████████ Login
17pt ███████████████ Send OTP
16pt ██████████████ Mobile Number
15pt █████████████ Input text / Hint
```

### Font Weights
```
Bold (700)      ████████ Welcome Back
Semibold (600)  ██████ Login, Button, Link
Medium (500)    ████ Label, Footer
Regular (400)   ██ Subtitle, Input
```

## Interactive States

### Input Field States
```
Default:
┌─────────────────────────────────┐
│ Enter your mobile number        │ ← #A3A3A3 hint
└─────────────────────────────────┘
Border: #E5E7EB

Focused:
┌─────────────────────────────────┐
│ 9876543210                      │ ← #111111 text
└─────────────────────────────────┘
Border: #2563EB (optional)

Filled:
┌─────────────────────────────────┐
│ 9876543210                      │ ← #111111 text
└─────────────────────────────────┘
Border: #E5E7EB
```

### Button States
```
Default:
┌─────────────────────────────────┐
│         Send OTP                │ ← #2563EB background
└─────────────────────────────────┘

Pressed:
┌─────────────────────────────────┐
│         Send OTP                │ ← Slightly darker
└─────────────────────────────────┘

Loading:
┌─────────────────────────────────┐
│            ⟳                    │ ← Spinner
└─────────────────────────────────┘

Disabled:
┌─────────────────────────────────┐
│         Send OTP                │ ← 50% opacity
└─────────────────────────────────┘
```

## Responsive Behavior

### iPhone 13 (390px)
```
┌────────────────────────────────┐
│ [Perfect fit - no adjustments] │
└────────────────────────────────┘
```

### Smaller Phones (< 375px)
```
┌──────────────────────────────┐
│ [Reduced padding & spacing]  │
│ Card padding: 24px           │
│ Top spacing: 100px           │
└──────────────────────────────┘
```

### Larger Phones (> 400px)
```
┌────────────────────────────────────┐
│     [Max width constraint]         │
│  ┌──────────────────────────┐     │
│  │ Card max width: 420px    │     │
│  │ Centered horizontally    │     │
│  └──────────────────────────┘     │
└────────────────────────────────────┘
```

### Tablets
```
┌──────────────────────────────────────────┐
│            [Centered card]               │
│     ┌──────────────────────────┐        │
│     │ Card max width: 480px    │        │
│     │ Centered on screen       │        │
│     └──────────────────────────┘        │
└──────────────────────────────────────────┘
```

## Implementation Code Snippets

### Gradient Background
```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF2F80ED),
        Color(0xFF2563EB),
      ],
    ),
  ),
)
```

### White Card
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFFFFFFFF),
    borderRadius: BorderRadius.circular(28),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.08),
        blurRadius: 20,
        offset: Offset(0, 4),
      ),
    ],
  ),
  padding: EdgeInsets.symmetric(
    horizontal: 28,
    vertical: 32,
  ),
)
```

### Input Field
```dart
Container(
  decoration: BoxDecoration(
    color: Color(0xFFF5F5F5),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: Color(0xFFE5E7EB),
      width: 1,
    ),
  ),
  child: TextField(
    style: TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w400,
      color: Color(0xFF111111),
    ),
    decoration: InputDecoration(
      hintText: 'Enter your mobile number',
      hintStyle: TextStyle(
        fontSize: 15,
        color: Color(0xFFA3A3A3),
      ),
      border: InputBorder.none,
      contentPadding: EdgeInsets.all(16),
    ),
  ),
)
```

### Primary Button
```dart
ElevatedButton(
  style: ElevatedButton.styleFrom(
    backgroundColor: Color(0xFF2563EB),
    foregroundColor: Color(0xFFFFFFFF),
    minimumSize: Size(double.infinity, 54),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    ),
    elevation: 0,
  ),
  child: Text(
    'Send OTP',
    style: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
    ),
  ),
  onPressed: () {},
)
```

---

**Use this guide** to understand the visual structure and implement pixel-perfect designs!
