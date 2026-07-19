# Product Detail Modal

## Overview
Pixel-perfect centered overlay modal for displaying full product details in the Marketplace feature.

## Files Created
- `lib/src/modals/product_detail_modal.dart` - Main modal widget with show helper
- `lib/src/components/condition_tag_widget.dart` - Green condition tag component
- `lib/src/components/seller_info_card.dart` - Seller information card
- `lib/src/components/primary_cta_button.dart` - Primary CTA button component
- `lib/src/components/read_more_text.dart` - Expandable text widget

## Features
- Centered overlay modal (not full-screen)
- Smooth fade + scale animation
- Semi-transparent dark scrim background
- Product image with condition tag and close button
- Product details: title, price, category badge
- Expandable description text
- Seller information card with location and phone
- Contact Seller CTA button
- Dismissible by tapping close button or outside modal

## Design Specs
- Modal width: 92% of viewport (max 420px)
- Modal corner radius: 18px
- Image height: 260px
- Background scrim: rgba(0,0,0,0.35)
- Primary blue: #2563EB
- Tag green: #17A861
- Seller card background: #F6F8FA

## Usage

### Basic Usage
```dart
import 'package:flutter/material.dart';
import 'src/modals/product_detail_modal.dart';
import 'src/models/marketplace_item.dart';

// Show modal
ProductDetailModal.show(context, marketplaceItem);
```

### Example with MarketplaceItem
```dart
final product = MarketplaceItem(
  id: '1',
  name: 'IKEA Study Table',
  price: 2500,
  category: 'Furniture',
  condition: 'Like New',
  imagePath: 'assets/marketplace/table.png',
);

// On card tap
GestureDetector(
  onTap: () {
    ProductDetailModal.show(context, product);
  },
  child: MarketplaceItemCard(item: product),
);
```

## Integration with Marketplace
The modal is already integrated in `marketplace_screen.dart`. Tapping any product card will open the modal.

## Phone Dialer Integration (Optional)
To enable actual phone calling, add `url_launcher` to `pubspec.yaml`:

```yaml
dependencies:
  url_launcher: ^6.2.0
```

Then uncomment the code in `product_detail_modal.dart`:

```dart
import 'package:url_launcher/url_launcher.dart';

// In PrimaryCTAButton onPressed:
final Uri phoneUri = Uri(scheme: 'tel', path: '+919876512345');
if (await canLaunchUrl(phoneUri)) {
  await launchUrl(phoneUri);
}
```

## Accessibility
- Semantic labels for images
- Tap targets >= 44×44 px
- Keyboard and safe area handling
- Screen reader support

## Animation Details
- Duration: 300ms
- Fade transition with easeOut curve
- Scale transition from 0.85 to 1.0 with easeOutCubic
- Smooth dismiss animation

## Customization
All components are reusable and can be customized:
- `ConditionTagWidget` - Change color or text
- `SellerInfoCard` - Modify layout or add fields
- `PrimaryCTAButton` - Change icon or action
- `ReadMoreText` - Adjust max lines or styling
