# Payment Method Modal - Asset Requirements

## Required Icon Assets

The payment method modal currently uses Flutter's built-in `Icons.credit_card_rounded` as a placeholder. For pixel-perfect design matching, export the following SVG icons from your design:

### Icon Files to Export:
1. `assets/icons/icon-upi.svg` - UPI payment icon (purple)
2. `assets/icons/icon-card.svg` - Credit/Debit card icon (blue)
3. `assets/icons/icon-bank.svg` - Net banking icon (green)
4. `assets/icons/icon-close.svg` - Close button icon (optional, currently using Material Icons)

### Icon Specifications:
- Format: SVG (vector)
- Size: 32x32 px (or scalable)
- Color: Will be applied programmatically
- Fallback: 2x/3x PNG if SVG not supported

### To Use Custom Icons:

1. Add `flutter_svg` package to `pubspec.yaml`:
```yaml
dependencies:
  flutter_svg: ^2.0.9
```

2. Add assets to `pubspec.yaml`:
```yaml
flutter:
  assets:
    - assets/icons/
```

3. Update the `PaymentMethodCard` widget to use SVG:
```dart
import 'package:flutter_svg/flutter_svg.dart';

// Replace Icon widget with:
SvgPicture.asset(
  iconAsset,
  width: 32,
  height: 32,
  colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
)
```

## Current Implementation

The modal is fully functional with Material Icons as placeholders. The design matches the reference image with:
- ✅ Centered modal overlay with dim background
- ✅ Exact spacing and padding (24px horizontal, 20px vertical)
- ✅ Three payment cards with proper styling
- ✅ Soft pastel icon backgrounds (purple, blue, green)
- ✅ Selection state with blue border and background tint
- ✅ Close button (X) in top-right
- ✅ Responsive and scrollable for small screens
- ✅ Proper shadows and rounded corners

## Usage

```dart
showPaymentMethodModal(context, (method) {
  print('Selected: $method');
  // Handle payment processing
});
```
