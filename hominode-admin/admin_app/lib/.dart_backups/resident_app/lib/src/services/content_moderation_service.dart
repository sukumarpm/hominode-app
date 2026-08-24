class ContentModerationService {
  // Banned keywords list
  static const List<String> bannedKeywords = [
    // Sexual content
    'sex', 'porn', 'escort', 'xxx', 'nude', 'naked', 'sexual',
    // Illegal activities
    'illegal', 'crime', 'criminal', 'steal', 'robbery', 'fraud',
    // Drugs
    'drug', 'cocaine', 'heroin', 'meth', 'weed', 'marijuana', 'cannabis',
    // Weapons
    'gun', 'weapon', 'bomb', 'explosive', 'rifle', 'pistol', 'knife',
    // Violence
    'kill', 'murder', 'violence', 'violent', 'assault', 'attack', 'hit',
    // Scams
    'scam', 'fake', 'fraud', 'fake id', 'counterfeit', 'phishing',
    // Hacking
    'hack', 'hacker', 'malware', 'virus', 'ransomware',
  ];

  /// Check if text content is safe
  /// Returns true if content is safe, false if it contains banned keywords
  static bool isTextSafe(String text) {
    if (text.isEmpty) return true;

    final lowerText = text.toLowerCase();

    for (final keyword in bannedKeywords) {
      if (lowerText.contains(keyword)) {
        print('❌ Banned keyword detected: $keyword');
        return false;
      }
    }

    print('✅ Text content is safe');
    return true;
  }

  /// Comprehensive content check (text only)
  /// Returns ModerationResult with safety status and reason
  Future<ModerationResult> checkContent({
    required String text,
  }) async {
    // Check text
    if (!isTextSafe(text)) {
      return ModerationResult(
        isSafe: false,
        reason: 'Your post contains banned keywords or inappropriate language.',
      );
    }

    return ModerationResult(
      isSafe: true,
      reason: 'Content is safe',
    );
  }
}

/// Result of content moderation check
class ModerationResult {
  final bool isSafe;
  final String reason;

  ModerationResult({
    required this.isSafe,
    required this.reason,
  });
}
