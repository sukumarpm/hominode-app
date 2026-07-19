# Multi-Language Visual Flow Diagram

## App Initialization Flow

```
┌─────────────────────────────────────────────────────────────┐
│                    App Starts                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         LanguageProvider Initializes                        │
│  - Create instance                                          │
│  - Call _initializeLanguage()                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│         Check if User Logged In                             │
│  - Get FirebaseAuth.instance.currentUser                    │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
    ┌─────────┐            ┌──────────┐
    │ Logged  │            │ Not      │
    │ In      │            │ Logged   │
    └────┬────┘            │ In       │
         │                 └────┬─────┘
         ▼                      │
    ┌──────────────────┐        │
    │ Fetch Saved      │        │
    │ Language from    │        │
    │ Firestore        │        │
    └────┬─────────────┘        │
         │                      │
         ▼                      │
    ┌──────────────────┐        │
    │ Found?           │        │
    └────┬─────────────┘        │
         │                      │
    ┌────┴────┐                 │
    │          │                │
    ▼          ▼                │
  ┌──┐      ┌──┐               │
  │Yes      │No                │
  └──┬──────┬──┘               │
     │      │                  │
     ▼      ▼                  ▼
  ┌──────────────────────────────────┐
  │ Use Saved Language or Default    │
  │ (Default: English)               │
  └────────────┬─────────────────────┘
               │
               ▼
  ┌──────────────────────────────────┐
  │ Load Translation JSON File       │
  │ lib/l10n/translations_{lang}.json│
  └────────────┬─────────────────────┘
               │
               ▼
  ┌──────────────────────────────────┐
  │ Initialize LocalizationService   │
  │ - Cache translations             │
  │ - Set current language           │
  └────────────┬─────────────────────┘
               │
               ▼
  ┌──────────────────────────────────┐
  │ App Ready with User's Language   │
  │ - All UI in correct language     │
  │ - RTL applied if Arabic          │
  └──────────────────────────────────┘
```

## Language Switching Flow

```
┌─────────────────────────────────────────────────────────────┐
│         User Selects Language in Settings                   │
│         (e.g., Tamil)                                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    LanguageProvider.setLanguage('ta') Called                │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Check if Same Language                                   │
│    (Skip if already Tamil)                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Set _isLoading = true                                    │
│    notifyListeners() - Show loading state                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    LocalizationService.changeLanguage('ta')                 │
│    - Load translations_ta.json                              │
│    - Cache translations                                     │
│    - Set _currentLanguage = 'ta'                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Save to Firestore                                        │
│    users/{userId}/language = 'ta'                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Increment rebuildCounter                                 │
│    _rebuildCounter++                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Set _isLoading = false                                   │
│    notifyListeners() - Trigger rebuild                      │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Consumer<LanguageProvider> Rebuilds                      │
│    - KeyedSubtree key changes                               │
│    - MaterialApp rebuilds                                   │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    MaterialApp Updates                                      │
│    - locale: Locale('ta')                                   │
│    - Directionality: LTR (Tamil is LTR)                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    All Widgets Rebuild                                      │
│    - LocalizedText widgets update                           │
│    - LocalizedButton widgets update                         │
│    - All text changes to Tamil                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Language Change Complete                                 │
│    - App displays in Tamil                                  │
│    - Preference saved to Firestore                          │
│    - Ready for next language change                         │
└─────────────────────────────────────────────────────────────┘
```

## RTL Layout Flow (Arabic)

```
┌─────────────────────────────────────────────────────────────┐
│         User Selects Arabic                                 │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    LanguageProvider.setLanguage('ar')                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Load Arabic Translations                                 │
│    lib/l10n/translations_ar.json                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Check isRTL()                                            │
│    - currentLanguage == 'ar' → true                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Update Directionality                                    │
│    textDirection: TextDirection.rtl                         │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Layout Mirroring Applied                                 │
│    - Text aligns right                                      │
│    - Buttons align right                                    │
│    - Icons align right                                      │
│    - Navigation drawer opens from right                     │
│    - Back button on right side                              │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Arabic UI Ready                                          │
│    - Full RTL layout                                        │
│    - Arabic text                                            │
│    - Proper text direction                                  │
└─────────────────────────────────────────────────────────────┘
```

## Translation Lookup Flow

```
┌─────────────────────────────────────────────────────────────┐
│    LocalizedText('home') Widget Renders                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Consumer<LanguageProvider> Listens                       │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Get Current Language                                     │
│    languageProvider.currentLanguageCode                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Call translate('home')                                   │
│    - Look up in _translations map                           │
│    - Key: 'home'                                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Found in Current Language?                               │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
    ┌─────────┐            ┌──────────┐
    │ Yes     │            │ No       │
    └────┬────┘            └────┬─────┘
         │                      │
         ▼                      ▼
    ┌──────────────┐        ┌──────────────┐
    │ Return       │        │ Return Key   │
    │ Translation  │        │ Name as      │
    │ (e.g., "Home"        │ Fallback     │
    │ or "முகப்பு")         │ (e.g., "home")
    └────┬─────────┘        └────┬─────────┘
         │                       │
         └───────────┬───────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Display Text in UI                                       │
│    Text(translatedValue)                                    │
└─────────────────────────────────────────────────────────────┘
```

## Firestore Persistence Flow

```
┌─────────────────────────────────────────────────────────────┐
│         Language Change Triggered                           │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Get Current User                                         │
│    FirebaseAuth.instance.currentUser                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    User Logged In?                                          │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
    ┌─────────┐            ┌──────────┐
    │ Yes     │            │ No       │
    └────┬────┘            │ Skip     │
         │                 │ Firestore│
         │                 │ Save     │
         ▼                 └──────────┘
    ┌──────────────────────┐
    │ Save to Firestore    │
    │ users/{userId}       │
    │ {                    │
    │   language: 'ta',    │
    │   updatedAt: now()   │
    │ }                    │
    └────┬─────────────────┘
         │
         ▼
    ┌──────────────────────┐
    │ Firestore Rules      │
    │ Check Permissions    │
    │ - User == userId?    │
    │ - Write allowed?     │
    └────┬─────────────────┘
         │
         ▼
    ┌──────────────────────┐
    │ Save Successful      │
    │ - Language saved     │
    │ - Timestamp updated  │
    │ - Ready for restore  │
    └──────────────────────┘
```

## App Restart with Saved Language

```
┌─────────────────────────────────────────────────────────────┐
│         App Restarts                                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    LanguageProvider Initializes                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    Check if User Logged In                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
         ┌───────────┴───────────┐
         │                       │
         ▼                       ▼
    ┌─────────┐            ┌──────────┐
    │ Yes     │            │ No       │
    └────┬────┘            │ Use      │
         │                 │ Default  │
         ▼                 │ (English)│
    ┌──────────────────┐   └──────────┘
    │ Query Firestore  │
    │ users/{userId}   │
    │ Get 'language'   │
    │ field            │
    └────┬─────────────┘
         │
         ▼
    ┌──────────────────┐
    │ Found Saved      │
    │ Language?        │
    └────┬─────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
  ┌──┐      ┌──┐
  │Yes      │No
  └──┬──────┬──┘
     │      │
     ▼      ▼
  ┌──────────────────────────────────┐
  │ Use Saved Language or Default    │
  │ (e.g., 'ta' or 'en')             │
  └────────────┬─────────────────────┘
               │
               ▼
  ┌──────────────────────────────────┐
  │ Load Translation JSON File       │
  │ lib/l10n/translations_{lang}.json│
  └────────────┬─────────────────────┘
               │
               ▼
  ┌──────────────────────────────────┐
  │ App Starts in Saved Language     │
  │ - No language selection needed   │
  │ - User's preference restored     │
  │ - Seamless experience            │
  └──────────────────────────────────┘
```

## Widget Rebuild Flow

```
┌─────────────────────────────────────────────────────────────┐
│    Language Change Detected                                 │
│    rebuildCounter incremented                               │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    notifyListeners() Called                                 │
│    - All Consumer widgets notified                          │
│    - All LocalizedText widgets notified                     │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    KeyedSubtree Key Changes                                 │
│    key: ValueKey(rebuildCounter)                            │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    MaterialApp Rebuilds                                     │
│    - New locale applied                                     │
│    - New Directionality applied                             │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    All Screens Rebuild                                      │
│    - Consumer widgets rebuild                               │
│    - LocalizedText widgets rebuild                          │
│    - LocalizedButton widgets rebuild                        │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    All Text Updates                                         │
│    - New translations loaded                                │
│    - New language displayed                                 │
│    - RTL applied if needed                                  │
└────────────────────┬────────────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────────────┐
│    UI Fully Updated                                         │
│    - Smooth 60 FPS transition                               │
│    - No crashes                                             │
│    - Ready for user interaction                             │
└─────────────────────────────────────────────────────────────┘
```

## Architecture Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                      MaterialApp                            │
│  ┌───────────────────────────────────────────────────────┐  │
│  │  Consumer<LanguageProvider>                           │  │
│  │  ┌─────────────────────────────────────────────────┐  │  │
│  │  │  KeyedSubtree(key: rebuildCounter)              │  │  │
│  │  │  ┌───────────────────────────────────────────┐  │  │  │
│  │  │  │  Directionality (RTL/LTR)                │  │  │  │
│  │  │  │  ┌─────────────────────────────────────┐  │  │  │  │
│  │  │  │  │  All Screens & Widgets              │  │  │  │  │
│  │  │  │  │  - LocalizedText                    │  │  │  │  │
│  │  │  │  │  - LocalizedButton                  │  │  │  │  │
│  │  │  │  │  - LocalizedAppBarTitle             │  │  │  │  │
│  │  │  │  │  - Consumer<LanguageProvider>       │  │  │  │  │
│  │  │  │  └─────────────────────────────────────┘  │  │  │  │
│  │  │  └───────────────────────────────────────────┘  │  │  │
│  │  └─────────────────────────────────────────────────┘  │  │
│  └───────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    LanguageProvider                  │
        │  ┌────────────────────────────────┐  │
        │  │ - currentLanguageCode          │  │
        │  │ - rebuildCounter               │  │
        │  │ - isLoading                    │  │
        │  │ - error                        │  │
        │  │                                │  │
        │  │ Methods:                       │  │
        │  │ - setLanguage()                │  │
        │  │ - translate()                  │  │
        │  │ - isRTL()                      │  │
        │  └────────────────────────────────┘  │
        └──────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    LocalizationService               │
        │  ┌────────────────────────────────┐  │
        │  │ - _translations (cached)       │  │
        │  │ - _currentLanguage             │  │
        │  │                                │  │
        │  │ Methods:                       │  │
        │  │ - initialize()                 │  │
        │  │ - changeLanguage()             │  │
        │  │ - translate()                  │  │
        │  │ - isRTL()                      │  │
        │  └────────────────────────────────┘  │
        └──────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    Translation JSON Files            │
        │  ┌────────────────────────────────┐  │
        │  │ lib/l10n/                      │  │
        │  │ - translations_en.json         │  │
        │  │ - translations_ta.json         │  │
        │  │ - translations_hi.json         │  │
        │  │ - translations_es.json         │  │
        │  │ - translations_ar.json         │  │
        │  └────────────────────────────────┘  │
        └──────────────────────────────────────┘
                           │
                           ▼
        ┌──────────────────────────────────────┐
        │    Firestore (users collection)      │
        │  ┌────────────────────────────────┐  │
        │  │ users/{userId}                 │  │
        │  │ {                              │  │
        │  │   language: "ta",              │  │
        │  │   updatedAt: timestamp         │  │
        │  │ }                              │  │
        │  └────────────────────────────────┘  │
        └──────────────────────────────────────┘
```

## Data Flow Diagram

```
User Input
    │
    ▼
┌─────────────────────────────────────┐
│ LanguageSelector Widget             │
│ User taps language button            │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ LanguageProvider.setLanguage()      │
│ - Load new translations             │
│ - Save to Firestore                 │
│ - Increment rebuildCounter          │
│ - notifyListeners()                 │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ Consumer<LanguageProvider>          │
│ - Detects change                    │
│ - Rebuilds widget tree              │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ LocalizedText Widgets               │
│ - Call translate(key)               │
│ - Get new translation               │
│ - Display new text                  │
└────────────┬────────────────────────┘
             │
             ▼
┌─────────────────────────────────────┐
│ UI Updated                          │
│ - All text in new language          │
│ - RTL applied if needed             │
│ - User sees new language            │
└─────────────────────────────────────┘
```

---

These diagrams show the complete flow of the multi-language system from initialization through language switching and persistence.
