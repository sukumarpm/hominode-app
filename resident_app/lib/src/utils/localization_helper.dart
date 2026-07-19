import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:easy_localization/easy_localization.dart';
import '../providers/language_provider.dart';

/// Localization Helper
/// Provides convenient methods to access translations throughout the app
class LocalizationHelper {
  /// Get translation from context using EasyLocalization
  static String translate(BuildContext context, String key, {Map<String, String>? params}) {
    return key.tr();
  }

  /// Short alias for translate
  static String t(BuildContext context, String key, {Map<String, String>? params}) {
    return translate(context, key, params: params);
  }

  /// Get current language code
  static String getCurrentLanguage(BuildContext context) {
    return context.read<LanguageProvider>().currentLanguageCode;
  }

  /// Get current language name
  static String getCurrentLanguageName(BuildContext context) {
    final provider = context.read<LanguageProvider>();
    return provider.getLanguageName(provider.currentLanguageCode);
  }

  /// Check if RTL (Arabic)
  static bool isRTL(BuildContext context) {
    return context.read<LanguageProvider>().isRTL();
  }

  /// Get text direction
  static TextDirection getTextDirection(BuildContext context) {
    final directionString = context.read<LanguageProvider>().getTextDirectionString();
    return directionString == 'rtl' ? TextDirection.rtl : TextDirection.ltr;
  }

  /// Change language
  static Future<void> changeLanguage(BuildContext context, String languageCode) async {
    await context.read<LanguageProvider>().setLanguage(languageCode);
  }

  /// Get all supported languages
  static List<String> getSupportedLanguages() {
    return LanguageProvider.supportedLanguages;
  }

  /// Get language names map
  static Map<String, String> getLanguageNames() {
    return LanguageProvider.languageNames;
  }

  /// Get language codes map
  static Map<String, String> getLanguageCodes() {
    return LanguageProvider.languageCodes;
  }

  /// Get language display code (e.g., 'EN', 'TA')
  static String getLanguageCode(String languageCode) {
    return LanguageProvider.languageCodes[languageCode] ?? languageCode.toUpperCase();
  }

  /// Get language display name
  static String getLanguageName(String languageCode) {
    return LanguageProvider.languageNames[languageCode] ?? languageCode;
  }
}

/// Extension on BuildContext for easier access
extension LocalizationExtension on BuildContext {
  /// Translate key
  String translate(String key, {Map<String, String>? params}) {
    return LocalizationHelper.translate(this, key, params: params);
  }

  /// Short alias
  String t(String key, {Map<String, String>? params}) {
    return LocalizationHelper.t(this, key, params: params);
  }

  /// Get current language
  String get currentLanguage => LocalizationHelper.getCurrentLanguage(this);

  /// Get current language name
  String get currentLanguageName => LocalizationHelper.getCurrentLanguageName(this);

  /// Check if RTL
  bool get isRTL => LocalizationHelper.isRTL(this);

  /// Get text direction
  TextDirection get textDirection => LocalizationHelper.getTextDirection(this);

  /// Change language
  Future<void> changeLanguage(String languageCode) async {
    await LocalizationHelper.changeLanguage(this, languageCode);
  }
}
