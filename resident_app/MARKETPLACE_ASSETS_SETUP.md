# Marketplace Assets Setup

## Required Assets

Create the following directory structure and add placeholder images:

```
resident_app/
  assets/
    marketplace/
      table.png
      bicycle.png
      cooler.png
      books.png
```

## Update pubspec.yaml

Add these lines to your `pubspec.yaml` under the `flutter:` section:

```yaml
flutter:
  assets:
    - assets/marketplace/table.png
    - assets/marketplace/bicycle.png
    - assets/marketplace/cooler.png
    - assets/marketplace/books.png
```

Or use wildcard:

```yaml
flutter:
  assets:
    - assets/marketplace/
```

## Quick Setup Commands

```bash
# Create directory
mkdir -p assets/marketplace

# Add placeholder images (you'll need to replace these with actual images)
# For now, the app will show a grey placeholder with an icon if images are missing
```

## Testing

After adding assets:
1. Run `flutter pub get`
2. Restart the app
3. Navigate to Dashboard → Marketplace

The screen will work even without images (shows grey placeholders).
