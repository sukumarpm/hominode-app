# App Language Settings - Complete Implementation

## Overview

A pixel-perfect language selection UI for the Lyvo resident app with support for multiple languages, RTL layouts, and seamless locale switching.

## Features

### Supported Languages

1. **English** (en) 🇺🇸 - LTR
2. **Hindi** (hi) 🇮🇳 - LTR - हिन्दी
3. **Tamil** (ta) 🇮🇳 - LTR - தமிழ்
4. **Spanish** (es) 🇪🇸 - LTR - Español
5. **Arabic** (ar) 🇸🇦 - RTL - العربية

### UI Components

✅ **Language List**
- Radio button selection
- Flag emoji indicators
- Native language names
- Current language badge
- RTL indicator badge

✅ **Apply & Restart Dialog**
- Confirmation modal
- Selected language preview
- Warning about app restart
- Loading indicator

✅ **Info Card**
- Blue info banner
- Explains restart requirement

✅ **Gradient Header**
- Matches app design
- Back navigation

## Files Created

```
lib/
├── src/
│   ├── screens/
│   │   └── language_settings_screen.dart    # Main screen
│   └── services/
│       └── locale_provider.dart              # Locale management
└── language_settings_demo.dart               # Demo app
```

## Quick Start

### 1. Test the Feature

```bash
flutter run lib/language_settings_demo.dart
```

### 2. Navigate from Settings

Already integrated! Go to:
```
Profile → Settings → App Language
```

### 3. Integration in Your App

```dart
import 'package:flutter/material.dart';
import 'src/screens/language_settings_screen.dart';

// Navigate to language settings
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => const LanguageSettingsScreen(),
  ),
);
```

## Localization Integration

### Step 1: Add Dependencies

Add to `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_localizations:
    sdk: flutter
  intl: ^0.18.1

flutter:
  generate: true
```

### Step 2: Create l10n.yaml

Create `l10n.yaml` in project root:

```yaml
arb-dir: lib/l10n
template-arb-file: app_en.arb
output-localization-file: app_localizations.dart
```

### Step 3: Create ARB Files

Create `lib/l10n/` directory with translation files:

**lib/l10n/app_en.arb** (English):
```json
{
  "@@locale": "en",
  "appTitle": "Lyvo",
  "dashboard": "Dashboard",
  "visitors": "Visitors",
  "bills": "Bills",
  "events": "Events",
  "profile": "Profile",
  "settings": "Settings",
  "notifications": "Notifications",
  "language": "Language",
  "logout": "Logout",
  "welcome": "Welcome",
  "helloUser": "Hello, {name}!",
  "@helloUser": {
    "description": "Greeting message with user name",
    "placeholders": {
      "name": {
        "type": "String",
        "example": "John"
      }
    }
  }
}
```

**lib/l10n/app_hi.arb** (Hindi):
```json
{
  "@@locale": "hi",
  "appTitle": "लिवो",
  "dashboard": "डैशबोर्ड",
  "visitors": "आगंतुक",
  "bills": "बिल",
  "events": "कार्यक्रम",
  "profile": "प्रोफ़ाइल",
  "settings": "सेटिंग्स",
  "notifications": "सूचनाएं",
  "language": "भाषा",
  "logout": "लॉग आउट",
  "welcome": "स्वागत है",
  "helloUser": "नमस्ते, {name}!"
}
```

**lib/l10n/app_ta.arb** (Tamil):
```json
{
  "@@locale": "ta",
  "appTitle": "லிவோ",
  "dashboard": "டாஷ்போர்டு",
  "visitors": "பார்வையாளர்கள்",
  "bills": "பில்கள்",
  "events": "நிகழ்வுகள்",
  "profile": "சுயவிவரம்",
  "settings": "அமைப்புகள்",
  "notifications": "அறிவிப்புகள்",
  "language": "மொழி",
  "logout": "வெளியேறு",
  "welcome": "வரவேற்கிறோம்",
  "helloUser": "வணக்கம், {name}!"
}
```

**lib/l10n/app_es.arb** (Spanish):
```json
{
  "@@locale": "es",
  "appTitle": "Lyvo",
  "dashboard": "Panel",
  "visitors": "Visitantes",
  "bills": "Facturas",
  "events": "Eventos",
  "profile": "Perfil",
  "settings": "Configuración",
  "notifications": "Notificaciones",
  "language": "Idioma",
  "logout": "Cerrar sesión",
  "welcome": "Bienvenido",
  "helloUser": "¡Hola, {name}!"
}
```

**lib/l10n/app_ar.arb** (Arabic - RTL):
```json
{
  "@@locale": "ar",
  "appTitle": "ليفو",
  "dashboard": "لوحة القيادة",
  "visitors": "الزوار",
  "bills": "الفواتير",
  "events": "الأحداث",
  "profile": "الملف الشخصي",
  "settings": "الإعدادات",
  "notifications": "الإشعارات",
  "language": "اللغة",
  "logout": "تسجيل الخروج",
  "welcome": "مرحبا",
  "helloUser": "مرحبا، {name}!"
}
```

### Step 4: Update main.dart

```dart
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'src/services/locale_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load saved locale
  final localeProvider = LocaleProvider();
  final savedLocale = await localeProvider.getLocale();
  
  runApp(MyApp(initialLocale: savedLocale));
}

class MyApp extends StatefulWidget {
  final Locale initialLocale;
  
  const MyApp({Key? key, required this.initialLocale}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
  
  // Static method to restart app
  static void setLocale(BuildContext context, Locale locale) {
    _MyAppState? state = context.findAncestorStateOfType<_MyAppState>();
    state?.setLocale(locale);
  }
}

class _MyAppState extends State<MyApp> {
  late Locale _locale;
  final LocaleProvider _localeProvider = LocaleProvider();

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _localeProvider.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    _localeProvider.removeListener(_onLocaleChanged);
    super.dispose();
  }

  void _onLocaleChanged() {
    setState(() {
      _locale = _localeProvider.currentLocale;
    });
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lyvo',
      debugShowCheckedModeBanner: false,
      
      // Localization delegates
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      
      // Supported locales
      supportedLocales: AppLocales.supported,
      
      // Current locale
      locale: _locale,
      
      // Locale resolution
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return supportedLocales.first;
        
        for (var supportedLocale in supportedLocales) {
          if (supportedLocale.languageCode == locale.languageCode) {
            return supportedLocale;
          }
        }
        
        return supportedLocales.first;
      },
      
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      
      home: const MainNavigationScreen(),
    );
  }
}
```

### Step 5: Use Translations in Code

```dart
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.dashboard),
      ),
      body: Column(
        children: [
          Text(l10n.welcome),
          Text(l10n.helloUser('John')),
          ElevatedButton(
            onPressed: () {},
            child: Text(l10n.logout),
          ),
        ],
      ),
    );
  }
}
```

## RTL Support

### Automatic RTL Detection

The app automatically detects RTL languages and adjusts layout:

```dart
// In your widgets
Widget build(BuildContext context) {
  final localeProvider = LocaleProvider();
  final isRTL = localeProvider.isRTL;
  
  return Directionality(
    textDirection: localeProvider.textDirection,
    child: YourWidget(),
  );
}
```

### RTL-Aware Widgets

```dart
// Use EdgeInsetsDirectional instead of EdgeInsets
padding: const EdgeInsetsDirectional.only(
  start: 16,  // Left in LTR, Right in RTL
  end: 16,    // Right in LTR, Left in RTL
  top: 8,
  bottom: 8,
)

// Use Align with AlignmentDirectional
Align(
  alignment: AlignmentDirectional.centerStart,  // Auto-adjusts for RTL
  child: Text('Hello'),
)

// Use Row with mainAxisAlignment
Row(
  mainAxisAlignment: MainAxisAlignment.start,  // Auto-adjusts for RTL
  children: [...],
)
```

### Testing RTL Layout

```dart
// Force RTL for testing
MaterialApp(
  locale: const Locale('ar'),
  builder: (context, child) {
    return Directionality(
      textDirection: TextDirection.rtl,
      child: child!,
    );
  },
  // ...
)
```

## Advanced Integration

### With Provider Package

```dart
// locale_provider.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en');

  Locale get locale => _locale;

  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}

// main.dart
void main() {
  runApp(
    ChangeNotifierProvider(
      create: (_) => LocaleProvider(),
      child: const MyApp(),
    ),
  );
}

// In widgets
final localeProvider = Provider.of<LocaleProvider>(context);
```

### With Riverpod

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

final localeProvider = StateNotifierProvider<LocaleNotifier, Locale>((ref) {
  return LocaleNotifier();
});

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(const Locale('en'));

  void setLocale(Locale locale) {
    state = locale;
  }
}

// In widgets
final locale = ref.watch(localeProvider);
```

### With GetX

```dart
import 'package:get/get.dart';

class LocaleController extends GetxController {
  var locale = const Locale('en').obs;

  void changeLocale(Locale newLocale) {
    locale.value = newLocale;
    Get.updateLocale(newLocale);
  }
}

// In main.dart
GetMaterialApp(
  locale: Get.deviceLocale,
  fallbackLocale: const Locale('en'),
  translations: AppTranslations(),
  // ...
)
```

## Persistence

### Using SharedPreferences

```dart
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider {
  Future<Locale> getLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString('language_code') ?? 'en';
    return Locale(languageCode);
  }

  Future<void> setLocale(Locale locale) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('language_code', locale.languageCode);
  }
}
```

## App Restart Methods

### Method 1: Phoenix Package

Add to `pubspec.yaml`:
```yaml
dependencies:
  flutter_phoenix: ^1.1.1
```

Wrap your app:
```dart
import 'package:flutter_phoenix/flutter_phoenix.dart';

void main() {
  runApp(
    Phoenix(
      child: const MyApp(),
    ),
  );
}

// To restart
Phoenix.rebirth(context);
```

### Method 2: Custom Restart Widget

```dart
class RestartWidget extends StatefulWidget {
  final Widget child;

  const RestartWidget({Key? key, required this.child}) : super(key: key);

  static void restartApp(BuildContext context) {
    context.findAncestorStateOfType<_RestartWidgetState>()?.restartApp();
  }

  @override
  _RestartWidgetState createState() => _RestartWidgetState();
}

class _RestartWidgetState extends State<RestartWidget> {
  Key key = UniqueKey();

  void restartApp() {
    setState(() {
      key = UniqueKey();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: key,
      child: widget.child,
    );
  }
}

// Wrap your app
void main() {
  runApp(
    RestartWidget(
      child: const MyApp(),
    ),
  );
}

// To restart
RestartWidget.restartApp(context);
```

### Method 3: Navigator Replacement

```dart
// Simple approach - replace entire navigation stack
Navigator.of(context).pushAndRemoveUntil(
  MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
  (route) => false,
);
```

## Design Specifications

### Colors

```dart
// Header Gradient
Color(0xFF2F6AF6) → Color(0xFF1D4CE6)

// Info Card
Background: Color(0xFFEFF6FF)
Border: Color(0xFFBFDBFE)
Text: Color(0xFF1E40AF)
Icon: Color(0xFF2563EB)

// Language Tile
Background: Colors.white
Border: Color(0xFFE5E7EB)
Selected Text: Color(0xFF2563EB)
Normal Text: Color(0xFF0F172A)
Subtitle: Color(0xFF9AA0A6)

// Current Badge
Background: Color(0xFF22C55E) with 10% opacity
Text: Color(0xFF22C55E)

// RTL Badge
Background: Color(0xFFF3F4F6)
Text: Color(0xFF6B7280)

// Warning Box
Background: Color(0xFFFEF3C7)
Border: Color(0xFFFDE68A)
Icon: Color(0xFFD97706)
Text: Colors.amber[900]
```

### Typography

```dart
// Header Title
fontSize: 22
fontWeight: FontWeight.w700
letterSpacing: -0.3

// Language Name
fontSize: 15
fontWeight: FontWeight.w500

// Native Name
fontSize: 13
color: Color(0xFF9AA0A6)

// Info Text
fontSize: 13
height: 1.4

// Dialog Title
fontSize: 18
fontWeight: FontWeight.w700

// Button Text
fontSize: 16
fontWeight: FontWeight.w600
```

### Spacing

```dart
// Screen padding
EdgeInsets.fromLTRB(16, 20, 16, 20)

// Section spacing
SizedBox(height: 24)

// Tile padding
EdgeInsets.symmetric(horizontal: 16, vertical: 14)

// Icon size
40x40 pixels

// Border radius
12px (cards, buttons)
16px (dialogs)
```

## Testing

### Unit Tests

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LocaleProvider', () {
    test('should return default locale', () async {
      final provider = LocaleProvider();
      final locale = await provider.getLocale();
      expect(locale.languageCode, 'en');
    });

    test('should set and get locale', () async {
      final provider = LocaleProvider();
      await provider.setLocale(const Locale('hi'));
      final locale = await provider.getLocale();
      expect(locale.languageCode, 'hi');
    });

    test('should detect RTL languages', () {
      final provider = LocaleProvider();
      provider.setLocale(const Locale('ar'));
      expect(provider.isRTL, true);
    });
  });
}
```

### Widget Tests

```dart
testWidgets('Language settings screen displays languages', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(
      home: LanguageSettingsScreen(),
    ),
  );

  expect(find.text('English'), findsOneWidget);
  expect(find.text('Hindi'), findsOneWidget);
  expect(find.text('Tamil'), findsOneWidget);
  expect(find.text('Spanish'), findsOneWidget);
});
```

## Troubleshooting

### Issue: Translations not updating
**Solution**: Run `flutter gen-l10n` or `flutter pub get` to regenerate localization files

### Issue: RTL layout not working
**Solution**: Ensure you're using `EdgeInsetsDirectional` and `AlignmentDirectional`

### Issue: App not restarting after language change
**Solution**: Implement one of the restart methods (Phoenix, RestartWidget, or Navigator replacement)

### Issue: Missing translations
**Solution**: Check that all ARB files have the same keys and run `flutter gen-l10n`

## Best Practices

1. **Always use l10n strings** - Never hardcode text
2. **Test RTL layouts** - Verify UI works in both directions
3. **Provide context** - Use `@` annotations in ARB files
4. **Handle plurals** - Use ICU message format for plurals
5. **Date/Time formatting** - Use `intl` package for locale-aware formatting
6. **Number formatting** - Format numbers according to locale
7. **Fallback locale** - Always provide English as fallback

## Resources

- [Flutter Internationalization](https://docs.flutter.dev/development/accessibility-and-localization/internationalization)
- [Intl Package](https://pub.dev/packages/intl)
- [ARB Format](https://github.com/google/app-resource-bundle/wiki/ApplicationResourceBundleSpecification)
- [RTL Support](https://docs.flutter.dev/development/accessibility-and-localization/internationalization#rtl-support)

---

**Version**: 1.0.0  
**Last Updated**: November 2025  
**Compatibility**: Flutter 3.0+
