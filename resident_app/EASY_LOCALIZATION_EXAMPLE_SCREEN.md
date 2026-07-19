# Example: Converting a Screen to EasyLocalization

## Before: Using Hardcoded Text

```dart
import 'package:flutter/material.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Welcome to Lyvo',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Quick Access Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Access',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickAccessCard('Visitors', Icons.people),
                      _buildQuickAccessCard('Billing', Icons.receipt),
                      _buildQuickAccessCard('Complaints', Icons.warning),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent Activity Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Activity',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('No recent activity'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(String title, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## After: Using EasyLocalization

```dart
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HomeScreen extends StatefulWidget {
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('home'.tr()),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'welcome'.tr(),
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            
            // Quick Access Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'quick_access'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildQuickAccessCard('visitors'.tr(), Icons.people),
                      _buildQuickAccessCard('billing'.tr(), Icons.receipt),
                      _buildQuickAccessCard('complaints'.tr(), Icons.warning),
                    ],
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Recent Activity Section
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'recent_activity'.tr(),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('no_data'.tr()),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(String title, IconData icon) {
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, size: 32),
              const SizedBox(height: 8),
              Text(title),
            ],
          ),
        ),
      ),
    );
  }
}
```

---

## Key Changes

### 1. Import EasyLocalization
```dart
import 'package:easy_localization/easy_localization.dart';
```

### 2. Replace Hardcoded Text
```dart
// Before
Text('Home')

// After
Text('home'.tr())
```

### 3. Use Translation Keys
All text now uses keys from JSON files:
- `'home'` → "Home" (en), "முகப்பு" (ta), etc.
- `'welcome'` → "Welcome" (en), "வரவேற்கிறோம்" (ta), etc.
- `'quick_access'` → "Quick Access" (en), "விரைவு அணுகல்" (ta), etc.

---

## Translation Keys Used

Add these to all 5 JSON files:

```json
{
  "home": "Home",
  "welcome": "Welcome to Lyvo",
  "quick_access": "Quick Access",
  "recent_activity": "Recent Activity",
  "visitors": "Visitors",
  "billing": "Billing",
  "complaints": "Complaints",
  "no_data": "No recent activity"
}
```

---

## Benefits of This Approach

✅ **Automatic Language Switching**
- Change language once, entire screen updates
- No manual refresh needed
- Works across all screens

✅ **Easy Maintenance**
- All translations in one place
- Easy to add new languages
- Easy to update existing translations

✅ **Better User Experience**
- Users see app in their preferred language
- Language preference persists
- Smooth transitions between languages

✅ **Scalability**
- Easy to add more languages
- Easy to add more translation keys
- No code changes needed for new translations

---

## Step-by-Step Conversion Process

### For Each Screen:

1. **Add import**
   ```dart
   import 'package:easy_localization/easy_localization.dart';
   ```

2. **Find all hardcoded text**
   - Search for `Text('...')`
   - Search for `AppBar(title: Text('...'))`
   - Search for `SnackBar(content: Text('...'))`

3. **Create translation keys**
   - Use descriptive key names
   - Add to all 5 JSON files

4. **Replace with `.tr()`**
   ```dart
   Text('key_name'.tr())
   ```

5. **Test**
   - Run app
   - Change language
   - Verify text updates

---

## Common Patterns

### AppBar Title
```dart
AppBar(
  title: Text('screen_name'.tr()),
)
```

### Button Labels
```dart
ElevatedButton(
  onPressed: () {},
  child: Text('save'.tr()),
)
```

### Error Messages
```dart
ScaffoldMessenger.of(context).showSnackBar(
  SnackBar(
    content: Text('error_message'.tr()),
  ),
)
```

### Dialog Titles
```dart
showDialog(
  context: context,
  builder: (context) => AlertDialog(
    title: Text('confirm'.tr()),
    content: Text('are_you_sure'.tr()),
  ),
)
```

### List Items
```dart
ListView.builder(
  itemBuilder: (context, index) {
    return ListTile(
      title: Text('item_title'.tr()),
    );
  },
)
```

---

## Testing Your Changes

1. **Test English**
   - Select English language
   - Verify all text displays correctly

2. **Test Tamil**
   - Select Tamil language
   - Verify all text displays in Tamil
   - Check for text overflow

3. **Test Arabic**
   - Select Arabic language
   - Verify RTL layout
   - Check text direction

4. **Test Persistence**
   - Change language
   - Close app
   - Reopen app
   - Verify language is restored

---

## Performance Tips

- Don't call `.tr()` in loops, store result in variable
- Use `.tr()` in build method, not in initState
- Avoid unnecessary rebuilds with `.tr()`

---

## Estimated Time

- Simple screen (5-10 text items): 5 minutes
- Medium screen (20-30 text items): 15 minutes
- Complex screen (50+ text items): 30 minutes

---

**Total Conversion Time:** ~2-3 hours for entire app

Start with the most important screens first!
