# Marketplace Feature

## Overview
Pixel-perfect marketplace screen with search, category filtering, and product grid.

## Files Created
- `lib/src/models/marketplace_item.dart` - Data model
- `lib/src/components/marketplace_search_bar.dart` - Search widget
- `lib/src/components/marketplace_filter_chips.dart` - Category filter chips
- `lib/src/components/marketplace_item_card.dart` - Product card widget
- `lib/src/screens/marketplace_screen.dart` - Main screen
- `lib/src/screens/add_marketplace_item_screen.dart` - Add item stub

## Assets Required
Add these placeholder images to `pubspec.yaml`:

```yaml
flutter:
  assets:
    - assets/marketplace/table.png
    - assets/marketplace/bicycle.png
    - assets/marketplace/cooler.png
    - assets/marketplace/books.png
```

Create the `assets/marketplace/` directory and add placeholder images.

## Integration with Dashboard

In `dashboard_screen.dart`, update the Marketplace quick action:

```dart
onTap: () {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => const MarketplaceScreen(),
    ),
  );
},
```

Import:
```dart
import 'src/screens/marketplace_screen.dart';
```

## Features
- Search functionality (case-insensitive)
- Category filtering (All, Furniture, Electronics, Other)
- 2-column responsive grid
- Condition tags (Like New, Good)
- Add item navigation
- Pixel-perfect design matching reference

## Design Specs
- Primary Color: #2563EB
- Background: #F7F7F7
- Card Background: #FFFFFF
- Rounded Corners: 16px
- Padding: 16px
- Gap: 12px
- Condition Tag Color: #10B981 (green)
