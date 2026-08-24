import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LanguageService {
  static const String _languageKey = 'selected_language';
  
  final _prefs = SharedPreferences.getInstance();
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  /// Get saved language from SharedPreferences
  Future<String> getSavedLanguage() async {
    try {
      final prefs = await _prefs;
      return prefs.getString(_languageKey) ?? 'en';
    } catch (e) {
      print('Error getting saved language: $e');
      return 'en';
    }
  }

  /// Save language to SharedPreferences and Firestore
  Future<bool> setLanguage(String languageCode) async {
    try {
      // Save to SharedPreferences
      final prefs = await _prefs;
      await prefs.setString(_languageKey, languageCode);
      
      // Save to Firestore if user is logged in
      final user = _auth.currentUser;
      if (user != null) {
        await _firestore.collection('users').doc(user.uid).update({
          'language': languageCode,
          'updatedAt': FieldValue.serverTimestamp(),
        }).catchError((e) {
          print('Error saving language to Firestore: $e');
          // Don't throw error, just log it
        });
      }
      
      return true;
    } catch (e) {
      print('Error setting language: $e');
      return false;
    }
  }

  /// Load language from Firestore for current user
  Future<String?> loadLanguageFromFirestore() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return null;
      
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        return doc.data()?['language'] as String?;
      }
      return null;
    } catch (e) {
      print('Error loading language from Firestore: $e');
      return null;
    }
  }

  /// Change app locale using EasyLocalization
  Future<void> changeLocale(String languageCode) async {
    try {
      final localeMap = {
        'en': const Locale('en'),
        'ta': const Locale('ta'),
        'hi': const Locale('hi'),
        'es': const Locale('es'),
        'ar': const Locale('ar'),
      };
      
      final locale = localeMap[languageCode] ?? const Locale('en');
      await EasyLocalization.of(EasyLocalization.of(EasyLocalization.of(null)!.context)!.context)!.setLocale(locale);
    } catch (e) {
      print('Error changing locale: $e');
    }
  }

  /// Get all supported languages
  static Map<String, String> getSupportedLanguages() {
    return {
      'en': 'English',
      'ta': 'Tamil',
      'hi': 'Hindi',
      'es': 'Spanish',
      'ar': 'العربية',
    };
  }

  /// Check if language is RTL
  static bool isRTL(String languageCode) {
    return languageCode == 'ar';
  }

  /// Get language name from code
  static String getLanguageName(String languageCode) {
    final languages = getSupportedLanguages();
    return languages[languageCode] ?? 'English';
  }
}
