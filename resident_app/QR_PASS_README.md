# Visitor QR Pass Screen

## Overview
Professional QR Pass display screen for approved visitors, showing a scannable QR code and visitor details.

## Features Implemented
✅ Blue gradient header with back button
✅ Large QR code display (240x240px)
✅ Pass ID badge
✅ Visitor details card with icons
✅ Status indicator (Approved in green)
✅ Instructions section with bullet points
✅ Clean, professional design
✅ Fully responsive layout

## Screen Sections

### 1. Header
- Blue gradient background matching app theme
- Back button to return to Visitor Management
- "Visitor QR Pass" title

### 2. QR Code Card
- Large white card with shadow
- 240x240px QR code placeholder (ready for actual QR generation)
- Border around QR code
- Pass ID badge below QR code
- Format: VIS-2024-001

### 3. Visitor Details Card
- Name with person icon
- Visit type with category icon
- Time with clock icon
- Status with checkmark icon (green for approved)
- Clean row layout with icons

### 4. Instructions Section
- Light blue background (#EAF1FF)
- Info icon and title
- Bullet-pointed instructions:
  - Show QR at security gate
  - Valid for single entry
  - Expires after scheduled time
  - Visitor must carry ID proof

### 5. Share Pass Button
- Full-width blue gradient button
- Share icon with "Share Pass" text
- Opens share options dialog
- Share methods:
  - SMS
  - Email
  - WhatsApp
  - Copy Link
- Success feedback after sharing

## Navigation
- Accessed from Visitor Management > Approved tab > "View QR Pass" button
- Receives visitor data as parameters (name, type, time)
- Back button returns to Visitor Management

## Color Palette
- Primary Blue: #2563EB
- Dark Blue: #1E40AF
- Light Blue Background: #EAF1FF
- Success Green: #10B981
- Background: #F8F9FA
- Text Gray: #64748B
- Dark Text: #1E293B

## Integration Notes

### QR Code Generation
The screen currently shows a QR icon placeholder. To integrate actual QR code:

1. Add QR code package to `pubspec.yaml`:
```yaml
dependencies:
  qr_flutter: ^4.1.0
```

2. Replace the QR placeholder with:
```dart
import 'package:qr_flutter/qr_flutter.dart';

QrImageView(
  data: 'VIS-2024-001-${visitorName}',
  version: QrVersions.auto,
  size: 240.0,
  backgroundColor: Colors.white,
)
```

### Pass ID Generation
Currently uses static format. Implement dynamic generation:
```dart
String generatePassId() {
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  return 'VIS-${DateTime.now().year}-${timestamp.toString().substring(8)}';
}
```

## File Location
```
lib/visitor_qr_screen.dart
```

## Usage Example
```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => VisitorQRScreen(
      visitorName: 'Amit Kumar',
      visitType: 'Personal Visit',
      time: '2:30 PM Today',
    ),
  ),
);
```

## Share Functionality

### Share Options Dialog
When clicking "Share Pass" button, a dialog appears with 4 sharing methods:

1. **Share via SMS**
   - Opens SMS app with pre-filled message
   - Includes pass details and QR code link

2. **Share via Email**
   - Opens email client
   - Includes pass details in email body
   - Attaches QR code image

3. **Share via WhatsApp**
   - Opens WhatsApp
   - Shares pass details and QR code

4. **Copy Link**
   - Copies shareable link to clipboard
   - Shows success message

### Share Dialog Design
- Rounded corners (16px)
- Title: "Share QR Pass"
- Each option has:
  - Icon in light blue container
  - Label text
  - Tappable area
- Cancel button at bottom

### Implementation Notes
Currently shows placeholder dialog with share options. To integrate actual sharing:

```dart
// For SMS sharing
import 'package:url_launcher/url_launcher.dart';

void _shareViaSMS() async {
  final uri = Uri.parse('sms:?body=Your visitor pass: [link]');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// For Email sharing
void _shareViaEmail() async {
  final uri = Uri.parse('mailto:?subject=Visitor Pass&body=Details...');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// For WhatsApp sharing
void _shareViaWhatsApp() async {
  final uri = Uri.parse('whatsapp://send?text=Your visitor pass: [link]');
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  }
}

// For copying link
import 'package:flutter/services.dart';

void _copyLink() {
  Clipboard.setData(ClipboardData(text: 'https://app.com/pass/VIS-2024-001'));
  // Show success message
}
```

## Future Enhancements
- ✅ Share QR code functionality (implemented)
- Add download QR code as image
- Add expiry timer countdown
- Add refresh/regenerate QR option
- Add visitor photo display
- Add gate entry history
- Add notification when visitor arrives
- Add share via social media (Facebook, Twitter)
- Add print QR pass option
- Add multiple recipient sharing
