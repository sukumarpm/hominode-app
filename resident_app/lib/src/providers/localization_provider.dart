// lib/src/providers/localization_provider.dart
// Localization Provider for State Management

import 'package:flutter/material.dart';
import '../services/localization_service.dart';

// ============================================================================
// LOCALIZATION PROVIDER
// ============================================================================
class LocalizationProvider extends ChangeNotifier {
  final LocalizationService _localizationService = LocalizationService();
  
  late String _currentLanguage;

  LocalizationProvider() {
    _currentLanguage = _localizationService.currentLanguage;
  }

  // ========================================================================
  // GETTERS
  // ========================================================================
  String get currentLanguage => _currentLanguage;
  bool get isRTL => _localizationService.isRTL();
  
  List<String> get supportedLanguages => LocalizationService.supportedLanguages;
  Map<String, String> get languageNames => LocalizationService.languageNames;

  // ========================================================================
  // LANGUAGE SWITCHING
  // ========================================================================
  Future<void> setLanguage(String languageCode) async {
    print('🔵 LocalizationProvider: Changing language to: $languageCode');
    
    try {
      await _localizationService.changeLanguage(languageCode);
      _currentLanguage = languageCode;
      
      print('✅ LocalizationProvider: Language changed successfully');
      notifyListeners();
    } catch (e) {
      print('❌ LocalizationProvider: Error changing language: $e');
    }
  }

  String getLanguageName(String languageCode) {
    return LocalizationService.languageNames[languageCode] ?? languageCode;
  }

  // ========================================================================
  // INITIALIZATION
  // ========================================================================
  Future<void> initialize() async {
    await _localizationService.initialize(_currentLanguage);
    _currentLanguage = _localizationService.currentLanguage;
    notifyListeners();
  }
}
