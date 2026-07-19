# Multi-Language Migration Example

This document shows how to migrate an existing screen from hardcoded text to full localization support.

## Before: Hardcoded Text

```dart
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        title: const Text('Profile'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFE6E6E6),
                    child: Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'John Doe',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'john@example.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Profile Info
            ListTile(
              leading: const Icon(Icons.phone),
              title: const Text('Phone'),
              subtitle: const Text('+1 234 567 8900'),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Apartment'),
              subtitle: const Text('A-101'),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Building'),
              subtitle: const Text('Tower A'),
            ),
            const Divider(),

            // Actions
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit Profile'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edit Profile')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: const Text('Change Password'),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Change Password')),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text('Logout'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Logout'),
                    content: const Text('Are you sure you want to logout?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Logout'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

## Step 1: Add Translation Keys

Add to all translation JSON files:

```json
// lib/l10n/translations_en.json
{
  "profile": "Profile",
  "phone": "Phone",
  "apartment": "Apartment",
  "building": "Building",
  "edit_profile": "Edit Profile",
  "change_password": "Change Password",
  "logout": "Logout",
  "are_you_sure_logout": "Are you sure you want to logout?",
  "confirm_logout": "Confirm Logout"
}

// lib/l10n/translations_ta.json
{
  "profile": "சுயவிவரம்",
  "phone": "தொலைபேசி",
  "apartment": "குடியிருப்பு",
  "building": "கட்டிடம்",
  "edit_profile": "சுயவிவரத்தைத் திருத்து",
  "change_password": "கடவுச்சொல்லை மாற்று",
  "logout": "வெளியேறு",
  "are_you_sure_logout": "நீங்கள் வெளியேற விரும்புகிறீர்களா?",
  "confirm_logout": "வெளியேறுவதை உறுதிப்படுத்து"
}

// lib/l10n/translations_hi.json
{
  "profile": "प्रोफ़ाइल",
  "phone": "फोन",
  "apartment": "अपार्टमेंट",
  "building": "बिल्डिंग",
  "edit_profile": "प्रोफ़ाइल संपादित करें",
  "change_password": "पासवर्ड बदलें",
  "logout": "लॉगआउट",
  "are_you_sure_logout": "क्या आप लॉगआउट करना चाहते हैं?",
  "confirm_logout": "लॉगआउट की पुष्टि करें"
}

// lib/l10n/translations_es.json
{
  "profile": "Perfil",
  "phone": "Teléfono",
  "apartment": "Apartamento",
  "building": "Edificio",
  "edit_profile": "Editar Perfil",
  "change_password": "Cambiar Contraseña",
  "logout": "Cerrar Sesión",
  "are_you_sure_logout": "¿Estás seguro de que deseas cerrar sesión?",
  "confirm_logout": "Confirmar Cierre de Sesión"
}

// lib/l10n/translations_ar.json
{
  "profile": "الملف الشخصي",
  "phone": "الهاتف",
  "apartment": "الشقة",
  "building": "المبنى",
  "edit_profile": "تحرير الملف الشخصي",
  "change_password": "تغيير كلمة المرور",
  "logout": "تسجيل الخروج",
  "are_you_sure_logout": "هل أنت متأكد من رغبتك في تسجيل الخروج؟",
  "confirm_logout": "تأكيد تسجيل الخروج"
}
```

## Step 2: Update Imports

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/localized_text.dart';
import '../utils/localization_helper.dart';
```

## Step 3: Migrate to Localized Widgets

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/language_provider.dart';
import '../widgets/localized_text.dart';
import '../utils/localization_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, _) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: const Color(0xFF2563EB),
            title: LocalizedAppBarTitle('profile'),
            leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
          ),
          body: SingleChildScrollView(
            child: Column(
              children: [
                // Profile Header
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      const CircleAvatar(
                        radius: 50,
                        backgroundColor: Color(0xFFE6E6E6),
                        child: Icon(Icons.person, size: 50),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'John Doe',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'john@example.com',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9B9B9B),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(),

                // Profile Info
                ListTile(
                  leading: const Icon(Icons.phone),
                  title: LocalizedText('phone'),
                  subtitle: const Text('+1 234 567 8900'),
                ),
                ListTile(
                  leading: const Icon(Icons.home),
                  title: LocalizedText('apartment'),
                  subtitle: const Text('A-101'),
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: LocalizedText('building'),
                  subtitle: const Text('Tower A'),
                ),
                const Divider(),

                // Actions
                ListTile(
                  leading: const Icon(Icons.edit),
                  title: LocalizedText('edit_profile'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: LocalizedText('edit_profile'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.lock),
                  title: LocalizedText('change_password'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: LocalizedText('change_password'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.logout),
                  title: LocalizedText('logout'),
                  onTap: () {
                    _showLogoutDialog(context);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: LocalizedText('confirm_logout'),
        content: LocalizedText('are_you_sure_logout'),
        actions: [
          LocalizedTextButton(
            'cancel',
            onPressed: () => Navigator.pop(context),
          ),
          LocalizedButton(
            'logout',
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}
```

## Step 4: Alternative Using Context Extension

```dart
import 'package:flutter/material.dart';
import '../utils/localization_helper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF2563EB),
        title: Text(context.translate('profile')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Profile Header
            Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 50,
                    backgroundColor: Color(0xFFE6E6E6),
                    child: Icon(Icons.person, size: 50),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'John Doe',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'john@example.com',
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF9B9B9B),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(),

            // Profile Info
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(context.translate('phone')),
              subtitle: const Text('+1 234 567 8900'),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: Text(context.translate('apartment')),
              subtitle: const Text('A-101'),
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: Text(context.translate('building')),
              subtitle: const Text('Tower A'),
            ),
            const Divider(),

            // Actions
            ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.translate('edit_profile')),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.translate('edit_profile')),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.lock),
              title: Text(context.translate('change_password')),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(context.translate('change_password')),
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.logout),
              title: Text(context.translate('logout')),
              onTap: () {
                _showLogoutDialog(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('confirm_logout')),
        content: Text(context.translate('are_you_sure_logout')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.translate('logout')),
          ),
        ],
      ),
    );
  }
}
```

## Comparison

| Aspect | Before | After |
|--------|--------|-------|
| Hardcoded Text | ✅ Yes | ❌ No |
| Language Support | ❌ No | ✅ Yes |
| RTL Support | ❌ No | ✅ Yes |
| Firestore Persistence | ❌ No | ✅ Yes |
| Dynamic Switching | ❌ No | ✅ Yes |
| Maintainability | ❌ Low | ✅ High |
| Scalability | ❌ Low | ✅ High |

## Migration Checklist

- [ ] Add translation keys to all JSON files
- [ ] Update imports
- [ ] Replace hardcoded text with LocalizedText
- [ ] Replace hardcoded button text with LocalizedButton
- [ ] Replace hardcoded app bar title with LocalizedAppBarTitle
- [ ] Replace hardcoded dialog text with LocalizedText
- [ ] Wrap screen in Consumer if needed
- [ ] Test language switching
- [ ] Test all languages
- [ ] Test RTL layout
- [ ] Verify Firestore persistence

## Tips

1. **Start with one screen** - Migrate one screen completely before moving to the next
2. **Use LocalizedText for simple cases** - It's the easiest and most efficient
3. **Use Consumer for complex screens** - When you need to rebuild the entire screen
4. **Test thoroughly** - Test all languages and RTL layout
5. **Keep translation keys consistent** - Use snake_case for all keys
6. **Group related keys** - Use prefixes like `settings_`, `error_`, etc.
7. **Document new keys** - Add comments explaining what each key is for
8. **Review translations** - Have native speakers review translations

## Common Mistakes to Avoid

❌ **Don't:** Mix hardcoded text and translations
```dart
Text('Home') // ❌ Hardcoded
LocalizedText('profile') // ✅ Localized
```

❌ **Don't:** Forget to add keys to all language files
```json
// translations_en.json
{ "my_key": "My Text" }

// translations_ta.json
// ❌ Missing "my_key"
```

❌ **Don't:** Use different key names in different files
```json
// translations_en.json
{ "home_title": "Home" }

// translations_ta.json
{ "home_heading": "முகப்பு" } // ❌ Different key name
```

❌ **Don't:** Forget to wrap in Consumer for language changes
```dart
// ❌ Won't update when language changes
Text(languageProvider.translate('home'))

// ✅ Will update when language changes
Consumer<LanguageProvider>(
  builder: (context, provider, _) => Text(provider.translate('home')),
)
```

## Next Steps

1. Identify all screens that need migration
2. Create a migration plan
3. Migrate screens one by one
4. Test thoroughly
5. Deploy to production
