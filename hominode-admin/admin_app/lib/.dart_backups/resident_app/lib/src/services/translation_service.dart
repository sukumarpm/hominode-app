import 'dart:convert';
import 'package:flutter/services.dart';

class TranslationService {
  static final TranslationService _instance = TranslationService._internal();
  
  factory TranslationService() {
    return _instance;
  }
  
  TranslationService._internal();

  final Map<String, Map<String, String>> _translations = {};
  late String _currentLanguage;

  Future<void> initialize(String languageCode) async {
    _currentLanguage = languageCode;
    await _loadTranslations(languageCode);
  }

  Future<void> _loadTranslations(String languageCode) async {
    try {
      final String jsonString = await rootBundle.loadString(
        'lib/l10n/translations_$languageCode.json',
      );
      final Map<String, dynamic> jsonMap = json.decode(jsonString);
      _translations[languageCode] = jsonMap.cast<String, String>();
      print('✅ Loaded translations for: $languageCode');
    } catch (e) {
      print('❌ Error loading translations for $languageCode: $e');
      // Fallback to English
      if (languageCode != 'en') {
        await _loadTranslations('en');
      }
    }
  }

  Future<void> changeLanguage(String languageCode) async {
    if (_currentLanguage == languageCode) return;
    
    _currentLanguage = languageCode;
    if (!_translations.containsKey(languageCode)) {
      await _loadTranslations(languageCode);
    }
    print('✅ Language changed to: $languageCode');
  }

  String translate(String key, {Map<String, String>? params}) {
    final translations = _translations[_currentLanguage] ?? {};
    String value = translations[key] ?? key;

    if (params != null) {
      params.forEach((paramKey, paramValue) {
        value = value.replaceAll('{$paramKey}', paramValue);
      });
    }

    return value;
  }

  String t(String key, {Map<String, String>? params}) {
    return translate(key, params: params);
  }

  String get currentLanguage => _currentLanguage;
}

// Global translation function
String tr(String key, {Map<String, String>? params}) {
  return TranslationService().translate(key, params: params);
}
