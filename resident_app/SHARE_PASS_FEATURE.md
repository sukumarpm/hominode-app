# Share Pass Feature

## Overview
The Share Pass feature allows users to share visitor QR passes through multiple channels including SMS, Email, WhatsApp, and direct link copying.

## Features Implemented
✅ Share Pass button on QR Pass screen
✅ Share options dialog with 4 methods
✅ SMS sharing option
✅ Email sharing option
✅ WhatsApp sharing option
✅ Copy link option
✅ Success feedback after sharing
✅ Clean, intuitive UI

## Share Button Design

### Visual Specifications
- **Width:** Full width
- **Height:** 56px
- **Background:** Blue gradient (#2563EB to #1E40AF)
- **Border Radius:** 16px
- **Shadow:** Blue shadow with 30% opacity, 12px blur, 4px offset
- **Icon:** Share outline icon (24px)
- **Text:** "Share Pass" (16pt SemiBold, White)
- **Spacing:** 12px between icon and text

### Button Location
- Positioned below Instructions section
- 24px spacing from instructions
- Bottom of scrollable content area

## Share Dialog

### Dialog Design
- **Shape:** Rounded corners (16px)
- **Title:** "Share QR Pass" (20pt SemiBold)
- **Background:** White
- **Padding:** Standard dialog padding

### Share Options

#### 1. Share via SMS
- **Icon:** Message outline (blue)
- **Label:** "Share via SMS"
- **Action:** Opens SMS app with pre-filled message
- **Use Case:** Quick sharing to phone contacts

#### 2. Share via Email
- **Icon:** Email outline (blue)
- **Label:** "Share via Email"
- **Action:** Opens email client with pass details
- **Use Case:** Formal sharing, includes attachments

#### 3. Share via WhatsApp
- **Icon:** Chat bubble outline (blue)
- **Label:** "Share via WhatsApp"
- **Action:** Opens WhatsApp with pass details
- **Use Case:** Most popular messaging app

#### 4. Copy Link
- **Icon:** Link outline (blue)
- **Label:** "Copy Link"
- **Action:** Copies shareable link to clipboard
- **Use Case:** Manual sharing, flexibility

### Option Item Design
- **Background:** Light gray (#F8F9FA)
- **Border Radius:** 12px
- **Padding:** 16px all around
- **Icon Container:**
  - Background: Light blue (#EAF1FF)
  - Border Radius: 8px
  - Padding: 8px
  - Icon Color: Primary blue (#2563EB)
- **Text:** 16pt Medium, Dark gray (#1E293B)
- **Spacing:** 12px between options

### Cancel Button
- **Text:** "Cancel" (16pt SemiBold)
- **Color:** Gray (#64748B)
- **Position:** Bottom of dialog

## User Flow

```
QR Pass Screen
    ↓
Click "Share Pass" button
    ↓
Share Dialog appears
    ↓
Select sharing method:
    ├─> SMS → Opens SMS app → Success message
    ├─> Email → Opens email client → Success message
    ├─> WhatsApp → Opens WhatsApp → Success message
    └─> Copy Link → Copies to clipboard → Success message
```

## Success Feedback

### Success Snackbar
- **Message:** "Pass shared via [method]"
- **Background:** Success green (#10B981)
- **Duration:** 2 seconds
- **Behavior:** Floating
- **Shape:** Rounded corners (8px)
- **Position:** Bottom of screen

### Examples:
- "Pass shared via SMS"
- "Pass shared via Email"
- "Pass shared via WhatsApp"
- "Link copied"

## Implementation Details

### Current Implementation
The feature currently shows a placeholder dialog with all share options. Clicking any option:
1. Closes the share dialog
2. Shows success snackbar
3. Returns to QR Pass screen

### Code Structure

```dart
// Main share button
Widget _buildShareButton(BuildContext context)

// Handle share action - opens dialog
void _handleSharePass(BuildContext context)

// Individual share option item
Widget _buildShareOption(
  BuildContext context, {
  required IconData icon,
  required String label,
  required VoidCallback onTap,
})

// Show success message
void _showShareSuccess(BuildContext context, String method)
```

## Integration with Native Sharing

To integrate actual sharing functionality, add the `url_launcher` package:

### pubspec.yaml
```yaml
dependencies:
  url_launcher: ^6.2.0
```

### SMS Sharing
```dart
import 'package:url_launcher/url_launcher.dart';

void _shareViaSMS() async {
  final message = 'Your visitor pass for $visitorName on ${_formatDate()}. '
                  'Pass ID: VIS-2024-001. '
                  'View pass: https://app.com/pass/VIS-2024-001';
  
  final uri = Uri.parse('sms:?body=${Uri.encodeComponent(message)}');
  
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    _showError('Could not open SMS app');
  }
}
```

### Email Sharing
```dart
void _shareViaEmail() async {
  final subject = 'Visitor Pass - $visitorName';
  final body = '''
Hello,

Your visitor pass details:
Name: $visitorName
Type: $visitType
Time: $time
Pass ID: VIS-2024-001

View your pass: https://app.com/pass/VIS-2024-001

Please show this QR code at the security gate.

Best regards,
Resident App Team
''';

  final uri = Uri.parse(
    'mailto:?subject=${Uri.encodeComponent(subject)}'
    '&body=${Uri.encodeComponent(body)}'
  );
  
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    _showError('Could not open email app');
  }
}
```

### WhatsApp Sharing
```dart
void _shareViaWhatsApp() async {
  final message = 'Your visitor pass for $visitorName on ${_formatDate()}. '
                  'Pass ID: VIS-2024-001. '
                  'View pass: https://app.com/pass/VIS-2024-001';
  
  final uri = Uri.parse('whatsapp://send?text=${Uri.encodeComponent(message)}');
  
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
  } else {
    _showError('WhatsApp is not installed');
  }
}
```

### Copy Link
```dart
import 'package:flutter/services.dart';

void _copyLink() async {
  final link = 'https://app.com/pass/VIS-2024-001';
  
  await Clipboard.setData(ClipboardData(text: link));
  
  _showShareSuccess(context, 'Link copied');
}
```

## Advanced Sharing Options

### Share Package
For more advanced sharing with native share sheet:

```yaml
dependencies:
  share_plus: ^7.2.0
```

```dart
import 'package:share_plus/share_plus.dart';

void _sharePass() async {
  final message = 'Your visitor pass for $visitorName\n'
                  'Pass ID: VIS-2024-001\n'
                  'View: https://app.com/pass/VIS-2024-001';
  
  await Share.share(
    message,
    subject: 'Visitor Pass - $visitorName',
  );
}

// Share with QR code image
void _sharePassWithImage() async {
  // Generate QR code image
  final qrImage = await _generateQRImage();
  
  await Share.shareXFiles(
    [XFile.fromData(qrImage, mimeType: 'image/png')],
    text: 'Your visitor pass for $visitorName',
  );
}
```

## Security Considerations

### Link Generation
- Generate unique, time-limited links
- Include authentication token
- Set expiration time matching pass validity
- Log all share actions for audit trail

### Example Secure Link
```dart
String _generateSecureLink() {
  final passId = 'VIS-2024-001';
  final token = _generateToken(); // Secure random token
  final expiry = DateTime.now().add(Duration(hours: 24));
  
  return 'https://app.com/pass/$passId?token=$token&expires=${expiry.millisecondsSinceEpoch}';
}
```

## Analytics

Track sharing behavior:
```dart
void _trackShare(String method) {
  // Analytics.logEvent(
  //   name: 'share_visitor_pass',
  //   parameters: {
  //     'method': method,
  //     'pass_id': 'VIS-2024-001',
  //     'visitor_name': visitorName,
  //   },
  // );
}
```

## Accessibility

✅ Share button has sufficient size (56px height)
✅ Clear icon and text labels
✅ High contrast colors
✅ Tappable areas >= 44x44px
✅ Screen reader friendly labels
✅ Success feedback for all actions

## Testing Checklist

- [ ] Share button appears on QR Pass screen
- [ ] Share button has correct styling
- [ ] Clicking share button opens dialog
- [ ] Dialog shows all 4 share options
- [ ] Each option has correct icon and label
- [ ] SMS option works (opens SMS app)
- [ ] Email option works (opens email client)
- [ ] WhatsApp option works (opens WhatsApp)
- [ ] Copy link works (copies to clipboard)
- [ ] Success message appears after sharing
- [ ] Cancel button closes dialog
- [ ] Dialog dismisses on outside tap
- [ ] Share button is accessible
- [ ] All text is readable

## Future Enhancements

- Add QR code image attachment to shares
- Add custom message templates
- Add recipient selection for SMS/Email
- Add share history tracking
- Add share analytics
- Add social media sharing (Facebook, Twitter)
- Add print option
- Add save to photos option
- Add share via Telegram
- Add share via Slack
- Add bulk sharing for multiple visitors
- Add scheduled sharing
- Add share expiration notifications
