# 🎯 Modern QR Gate Scanner - Flow UI Specification

**Date:** December 17, 2025  
**Status:** Ready for Implementation  
**Design System:** Flow UI

---

## 🎨 **DESIGN OVERVIEW**

A clean, modern QR scanner interface following Flow UI principles with:
- Minimalist black background
- Blue accent color (#2563EB)
- Smooth animations
- Clear visual hierarchy
- Simple, intuitive controls

---

## 📱 **SCREEN LAYOUT**

```
┌─────────────────────────────────────────┐
│  [←]        QR Gate Scanner        [⚡]  │  <- Top Bar
│                                          │
│                                          │
│          [Camera Preview Area]           │
│                                          │
│         ┌──────────────────┐            │
│         │                  │            │
│         │   [QR Scanner]   │            │  <- Scanning Frame
│         │                  │            │
│         │  Position QR     │            │
│         │  within frame    │            │
│         │                  │            │
│         │ [Tap to scan]    │            │
│         │                  │            │
│         └──────────────────┘            │
│                                          │
│                                          │
│  [Manual Entry]      [Recent Scans]     │  <- Bottom Controls
└─────────────────────────────────────────┘
```

---

## 🎨 **COLOR SCHEME**

```dart
// Background
Background: #000000 (Black)
Camera Preview: Gradient(#1F2937, #111827, #1F2937)

// Primary Actions
Primary Blue: #2563EB
Primary Blue Light: rgba(37, 99, 235, 0.3)

// Scanner Frame
Frame Border: rgba(255, 255, 255, 0.5)
Corner Indicators: #2563EB
Scan Line: #2563EB with gradient

// Text
Primary Text: #FFFFFF (White)
Secondary Text: rgba(255, 255, 255, 0.8)
Hint Text: rgba(255, 255, 255, 0.6)

// Status Colors
Success (Entry): #10B981 (Green)
Warning (Exit): #F59E0B (Orange)
Error: #DC2626 (Red)

// Backgrounds
Button Background: #2563EB
Icon Button: rgba(0, 0, 0, 0.5)
Active Icon: rgba(37, 99, 235, 0.3)
```

---

## 🔧 **COMPONENTS**

### **1. Top Bar**
- Back button (left)
- Title "QR Gate Scanner" (center)
- Flash toggle (right)
- Semi-transparent black background
- White icons and text

### **2. Scanning Frame**
- 280x280px square
- Rounded corners (20px)
- White border (2px, 50% opacity)
- Blue corner indicators (4px thick)
- Animated scan line (blue gradient)
- Center icon and instructions

### **3. Bottom Controls**
- Two primary buttons
- Blue background
- White text and icons
- Rounded corners (14px)
- Horizontal layout

### **4. Success Dialog**
- Rounded container (20px)
- Large status icon (64px circle)
- Visitor information rows
- Time stamp badge
- Full-width action button

### **5. Error Dialog**
- Similar to success dialog
- Red color scheme
- Error icon
- Error message
- Single OK button

---

## ⚡ **ANIMATIONS**

### **Scan Line Animation**
```dart
AnimationController(
  duration: Duration(seconds: 2),
  vsync: this,
)..repeat();

// Moves from top to bottom continuously
// Blue gradient effect
// Pauses when processing
```

### **Corner Indicators**
- Static blue corners
- 24x24px size
- 4px border width
- Positioned at frame corners

### **Processing State**
- Overlay with 70% black opacity
- White rounded container
- Blue circular progress indicator
- "Processing QR Code..." text

---

## 🎯 **USER FLOW**

### **Normal Scan Flow**
1. User opens QR scanner
2. Camera preview shows
3. Scan line animates
4. User positions QR code
5. Tap to simulate scan
6. Processing indicator shows
7. Success/Error dialog appears
8. User confirms and exits

### **Manual Entry Flow**
1. User taps "Manual Entry"
2. Dialog with text input appears
3. User enters QR code (VIS001, VIS002, etc.)
4. User taps "Process"
5. Same processing as scan flow

### **Recent Scans Flow**
1. User taps "Recent Scans"
2. Dialog shows scan history
3. User can review past scans
4. User closes dialog

---

## 📊 **VISITOR DATA STRUCTURE**

```dart
Map<String, Map<String, dynamic>> {
  'VIS001': {
    'id': 'VIS001',
    'visitorName': 'Rajesh Kumar',
    'phone': '+91 98765 11111',
    'residentName': 'Priya Sharma',
    'unit': 'A-101',
    'purpose': 'Personal Visit',
    'status': 'approved',
    'isInside': false,  // Toggle on entry/exit
  },
  // More visitors...
}
```

---

## ✅ **SUCCESS DIALOG DESIGN**

```
┌─────────────────────────────────┐
│                                 │
│         [✓ Icon Circle]         │  <- Green/Orange
│                                 │
│        Entry Granted /          │  <- Title
│        Exit Recorded            │
│                                 │
│  [👤] Rajesh Kumar             │  <- Info Rows
│  [🏠] Unit A-101 - Priya       │
│  [📝] Personal Visit           │
│                                 │
│  ┌───────────────────────────┐ │
│  │ 🕐 Entry time: 2:30 PM    │ │  <- Time Badge
│  └───────────────────────────┘ │
│                                 │
│  [        Done Button        ]  │  <- Action
│                                 │
└─────────────────────────────────┘
```

---

## ❌ **ERROR DIALOG DESIGN**

```
┌─────────────────────────────────┐
│                                 │
│         [⚠ Icon Circle]         │  <- Red
│                                 │
│        Invalid QR Code          │  <- Title
│                                 │
│   QR code not found in the      │  <- Message
│   system.                       │
│                                 │
│  [         OK Button         ]  │  <- Action
│                                 │
└─────────────────────────────────┘
```

---

## 🎮 **INTERACTIVE ELEMENTS**

### **Tap Actions**
1. **Back Button** - Navigate back
2. **Flash Toggle** - Toggle flashlight
3. **Scanning Frame** - Show simulation dialog
4. **Manual Entry** - Open manual input dialog
5. **Recent Scans** - Show scan history

### **Haptic Feedback**
- Light impact on flash toggle
- Medium impact on successful scan
- No feedback on errors

---

## 🔄 **STATE MANAGEMENT**

```dart
// States
bool _flashOn = false;
bool _isProcessing = false;
String? _lastScannedCode;

// Controllers
AnimationController _scanLineController;

// Data
Map<String, Map<String, dynamic>> _mockVisitorDatabase;
```

---

## 📝 **IMPLEMENTATION CHECKLIST**

### **Core Functionality**
- [ ] Camera preview placeholder
- [ ] Scanning frame with corners
- [ ] Animated scan line
- [ ] Flash toggle
- [ ] QR code processing
- [ ] Entry/Exit toggle logic
- [ ] Success dialog
- [ ] Error dialog

### **Additional Features**
- [ ] Manual entry dialog
- [ ] Recent scans dialog
- [ ] Simulation mode
- [ ] Haptic feedback
- [ ] Processing indicator
- [ ] Time formatting

### **UI Polish**
- [ ] Smooth animations
- [ ] Proper spacing
- [ ] Consistent colors
- [ ] Rounded corners
- [ ] Icon sizing
- [ ] Text hierarchy

---

## 🎨 **DESIGN PRINCIPLES APPLIED**

1. **Minimalism** - Clean black background, minimal UI elements
2. **Focus** - Scanning frame is the primary focus
3. **Clarity** - Clear instructions and feedback
4. **Consistency** - Blue accent color throughout
5. **Feedback** - Visual and haptic feedback for actions
6. **Simplicity** - Two main actions, easy to understand
7. **Modern** - Rounded corners, gradients, smooth animations

---

## 🚀 **FUTURE ENHANCEMENTS**

1. **Real Camera Integration** - Use actual camera package
2. **Sound Effects** - Beep on successful scan
3. **Vibration Patterns** - Different patterns for entry/exit
4. **Scan History** - Store and display recent scans
5. **Statistics** - Show daily entry/exit counts
6. **Filters** - Filter by visitor type, time, etc.
7. **Export** - Export scan logs
8. **Offline Mode** - Cache visitor data for offline scanning

---

## 📦 **REQUIRED PACKAGES**

```yaml
# For real QR scanning (optional)
dependencies:
  qr_code_scanner: ^1.0.1  # Or mobile_scanner: ^3.5.2
  
# Current implementation uses:
  flutter/material.dart
  flutter/services.dart  # For haptic feedback
```

---

## 🎉 **SUMMARY**

The modern QR Gate Scanner follows Flow UI principles with:
- ✅ Clean, minimalist design
- ✅ Blue accent color scheme
- ✅ Smooth animations
- ✅ Clear visual hierarchy
- ✅ Simple, intuitive controls
- ✅ Proper feedback mechanisms
- ✅ Entry/Exit tracking
- ✅ Error handling
- ✅ Simulation mode for testing

**Key Features:**
- Animated scanning frame
- Flash toggle
- Manual entry option
- Recent scans history
- Success/Error dialogs
- Haptic feedback
- Processing indicator

---

**Last Updated:** December 17, 2025
