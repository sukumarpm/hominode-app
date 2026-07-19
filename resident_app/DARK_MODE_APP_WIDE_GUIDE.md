# Dark Mode - App-Wide Integration Guide

## 🎯 Goal

Make dark mode work seamlessly across ALL screens in your Lyvo app with consistent, beautiful UI.

## 📋 Quick Setup (5 Steps)

### Step 1: Update main.dart

Replace your current `main.dart` with this:

```dart
import 'package:flutter/material.dart';
import 'src/providers/theme_provider.dart';
import 'main_navigation.dart'; // Your main navigation screen

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved theme
  final themeProvider = ThemeProvider();
  await themeProvider.loadTheme();
  
  runApp(MyApp(themeProvider: themeProvider));
}

class MyApp extends StatefulWidget {
  final ThemeProvider themeProvider;
  
  const MyApp({Key? key, required this.themeProvider}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void initState() {
    super.initState();
    widget.themeProvider.addListener(_onThemeChanged);
  }

  @override
  void dispose() {
    widget.themeProvider.removeListener(_onThemeChanged);
    super.dispose();
  }

  void _onThemeChanged() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      
      // Apply themes
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: widget.themeProvider.materialThemeMode,
      
      home: const MainNavigationScreen(),
    );
  }
}
```

### Step 2: Replace Hardcoded Colors

**BEFORE (❌ Don't do this):**
```dart
Container(
  color: Color(0xFFFAFBFC),  // Hardcoded color
  child: Text(
    'Hello',
    style: TextStyle(color: Color(0xFF0F172A)),  // Hardcoded
  ),
)
```

**AFTER (✅ Do this):**
```dart
Container(
  color: Theme.of(context).scaffoldBackgroundColor,  // Theme-aware
  child: Text(
    'Hello',
    style: Theme.of(context).textTheme.bodyLarge,  // Theme-aware
  ),
)
```

### Step 3: Update All Screens

For EVERY screen in your app, replace hardcoded colors with theme colors:

```dart
class MyScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);  // Get theme once
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,  // Use theme
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text('Title', style: theme.textTheme.titleLarge),
      ),
      body: Container(
        color: theme.cardColor,  // Use theme
        child: Text(
          'Content',
          style: theme.textTheme.bodyLarge,  // Use theme
        ),
      ),
    );
  }
}
```

### Step 4: Update Components

Update all reusable components:

```dart
class MyCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Container(
      decoration: BoxDecoration(
        color: theme.cardColor,  // Auto dark/light
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.dividerColor,  // Auto dark/light
        ),
      ),
      child: Text(
        'Card Content',
        style: theme.textTheme.bodyMedium,  // Auto dark/light
      ),
    );
  }
}
```

### Step 5: Test Dark Mode

1. Run your app
2. Go to Settings → App Theme
3. Toggle to Dark mode
4. Navigate through ALL screens
5. Verify everything looks good

## 🎨 Theme Color Reference

### Use These Instead of Hardcoded Colors

```dart
final theme = Theme.of(context);

// Backgrounds
theme.scaffoldBackgroundColor  // Screen background
theme.cardColor                // Card background
theme.colorScheme.surface      // Surface color

// Text
theme.textTheme.displayLarge   // Large heading
theme.textTheme.headlineMedium // Medium heading
theme.textTheme.titleLarge     // Title
theme.textTheme.bodyLarge      // Body text
theme.textTheme.bodyMedium     // Secondary text
theme.textTheme.bodySmall      // Small text

// Colors
theme.primaryColor             // Primary blue
theme.colorScheme.primary      // Primary color
theme.colorScheme.secondary    // Secondary color
theme.colorScheme.error        // Error red
theme.dividerColor             // Divider/border

// Icons
theme.iconTheme.color          // Icon color

// Check if dark
theme.brightness == Brightness.dark
```

## 📱 Screen-by-Screen Updates

### Dashboard Screen

```dart
// BEFORE
Scaffold(
  backgroundColor: Color(0xFFFAFBFC),
  body: Container(
    color: Colors.white,
    child: Text('Dashboard', style: TextStyle(color: Color(0xFF0F172A))),
  ),
)

// AFTER
Scaffold(
  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
  body: Container(
    color: Theme.of(context).cardColor,
    child: Text('Dashboard', style: Theme.of(context).textTheme.bodyLarge),
  ),
)
```

### Settings Screen

Already updated! ✅ The settings screen you have uses theme colors.

### Profile Screen

```dart
// Update hardcoded colors
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [
        Theme.of(context).primaryColor,
        Theme.of(context).primaryColorDark,
      ],
    ),
  ),
)
```

### Cards/Lists

```dart
// Card widget
Card(
  color: Theme.of(context).cardColor,  // Auto dark/light
  child: ListTile(
    title: Text('Item', style: Theme.of(context).textTheme.titleMedium),
    subtitle: Text('Details', style: Theme.of(context).textTheme.bodySmall),
  ),
)
```

## 🔧 Common Patterns

### Pattern 1: Gradient Headers

```dart
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: Theme.of(context).brightness == Brightness.dark
          ? [Color(0xFF1E293B), Color(0xFF0F172A)]  // Dark gradient
          : [Color(0xFF2F6AF6), Color(0xFF1D4CE6)],  // Light gradient
    ),
  ),
)
```

### Pattern 2: Conditional Colors

```dart
Container(
  color: Theme.of(context).brightness == Brightness.dark
      ? Color(0xFF1E293B)  // Dark mode color
      : Colors.white,       // Light mode color
)
```

### Pattern 3: Icon Colors

```dart
Icon(
  Icons.home,
  color: Theme.of(context).iconTheme.color,  // Auto dark/light
)
```

### Pattern 4: Button Styles

```dart
ElevatedButton(
  onPressed: () {},
  style: ElevatedButton.styleFrom(
    backgroundColor: Theme.of(context).primaryColor,
    foregroundColor: Colors.white,
  ),
  child: Text('Button'),
)
```

### Pattern 5: Input Fields

```dart
TextField(
  decoration: InputDecoration(
    filled: true,
    fillColor: Theme.of(context).cardColor,
    border: OutlineInputBorder(
      borderSide: BorderSide(
        color: Theme.of(context).dividerColor,
      ),
    ),
  ),
  style: Theme.of(context).textTheme.bodyLarge,
)
```

## 🎯 Checklist for Each Screen

For EVERY screen, check these:

- [ ] `backgroundColor` uses theme color
- [ ] All `Container` colors use theme
- [ ] All `Text` uses theme text styles
- [ ] All `Icon` colors use theme
- [ ] All `Card` colors use theme
- [ ] All borders use `theme.dividerColor`
- [ ] Gradients have dark mode variants
- [ ] Buttons use theme colors
- [ ] Input fields use theme colors
- [ ] Modals/Dialogs use theme colors

## 🚀 Quick Fix Script

Search and replace these patterns in your code:

```dart
// Find: Color(0xFFFAFBFC)
// Replace: Theme.of(context).scaffoldBackgroundColor

// Find: Color(0xFFFFFFFF) or Colors.white (for backgrounds)
// Replace: Theme.of(context).cardColor

// Find: Color(0xFF0F172A) (for text)
// Replace: Theme.of(context).textTheme.bodyLarge?.color

// Find: Color(0xFF6B7280) (for secondary text)
// Replace: Theme.of(context).textTheme.bodyMedium?.color

// Find: Color(0xFFE5E7EB) (for borders)
// Replace: Theme.of(context).dividerColor
```

## 📊 Color Mapping

### Light Mode → Dark Mode

| Light Color | Usage | Dark Color | Theme Property |
|-------------|-------|------------|----------------|
| #FAFBFC | Background | #0F172A | `scaffoldBackgroundColor` |
| #FFFFFF | Cards | #1E293B | `cardColor` |
| #0F172A | Text | #F8FAFC | `textTheme.bodyLarge` |
| #6B7280 | Secondary | #CBD5E1 | `textTheme.bodyMedium` |
| #E5E7EB | Borders | #334155 | `dividerColor` |
| #2563EB | Primary | #3B82F6 | `primaryColor` |

## 🎨 Example: Complete Screen Update

**BEFORE:**
```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAFBFC),
      appBar: AppBar(
        backgroundColor: Color(0xFF2563EB),
        title: Text('Dashboard', style: TextStyle(color: Colors.white)),
      ),
      body: Container(
        color: Colors.white,
        child: Column(
          children: [
            Text('Welcome', style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0F172A),
            )),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: Color(0xFFE5E7EB)),
              ),
              child: Text('Card', style: TextStyle(color: Color(0xFF6B7280))),
            ),
          ],
        ),
      ),
    );
  }
}
```

**AFTER:**
```dart
class DashboardScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.primaryColor,
        title: Text('Dashboard', style: theme.appBarTheme.titleTextStyle),
      ),
      body: Container(
        color: theme.scaffoldBackgroundColor,
        child: Column(
          children: [
            Text('Welcome', style: theme.textTheme.displaySmall),
            Container(
              decoration: BoxDecoration(
                color: theme.cardColor,
                border: Border.all(color: theme.dividerColor),
              ),
              child: Text('Card', style: theme.textTheme.bodyMedium),
            ),
          ],
        ),
      ),
    );
  }
}
```

## 🔍 Testing Dark Mode

### Manual Testing

1. **Enable Dark Mode**
   - Go to Settings → App Theme
   - Toggle to Dark

2. **Test Each Screen**
   - Dashboard
   - Visitors
   - Bills
   - Events
   - Profile
   - All sub-screens

3. **Check These Elements**
   - Text is readable
   - Cards have proper contrast
   - Buttons are visible
   - Icons are visible
   - Borders are visible
   - Gradients look good

### Automated Testing

```dart
testWidgets('Screen works in dark mode', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.dark,
      home: MyScreen(),
    ),
  );

  // Verify screen renders
  expect(find.byType(MyScreen), findsOneWidget);
});
```

## 💡 Pro Tips

1. **Always use `Theme.of(context)`** - Never hardcode colors
2. **Test both themes** - Switch between light/dark frequently
3. **Use theme text styles** - Don't create custom TextStyles
4. **Gradients need variants** - Provide both light and dark versions
5. **Check contrast** - Ensure text is readable in both modes
6. **Update modals too** - Don't forget dialogs and bottom sheets
7. **System UI** - Update status bar color for dark mode

## 🐛 Common Issues

### Issue: White flash when switching themes
**Solution**: Ensure all screens use theme colors, not hardcoded

### Issue: Text not visible in dark mode
**Solution**: Use `theme.textTheme` instead of custom colors

### Issue: Cards blend with background
**Solution**: Use `theme.cardColor` for cards, not background color

### Issue: Gradients look bad in dark mode
**Solution**: Provide dark mode gradient variants

## 📚 Next Steps

1. ✅ Update `main.dart` with ThemeProvider
2. ✅ Replace all hardcoded colors with theme colors
3. ✅ Test dark mode on all screens
4. ✅ Fix any contrast issues
5. ✅ Update all components
6. ✅ Test with real users

## 🎉 Result

After following this guide, your app will:
- ✅ Support dark mode everywhere
- ✅ Have consistent UI in both themes
- ✅ Automatically adapt to theme changes
- ✅ Look professional and polished
- ✅ Be easy to maintain

---

**Need help?** Check `THEME_SETTINGS_README.md` for detailed theme documentation.
