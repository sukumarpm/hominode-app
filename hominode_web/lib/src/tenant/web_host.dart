import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

enum WebSurface {
  marketing,
  admin,
  residentCommunity,
  localDevelopment,
  invalid,
}

class CommunitySlugPolicy {
  const CommunitySlugPolicy._();

  static const int minLength = 3;
  static const int maxLength = 63;
  static const Set<String> reserved = {
    'admin',
    'about',
    'api',
    'app',
    'assets',
    'auth',
    'c',
    'cdn',
    'contact',
    'docs',
    'features',
    'firebase',
    'help',
    'home',
    'legal',
    'login',
    'mail',
    'pricing',
    'privacy',
    'resident',
    'static',
    'status',
    'support',
    'super-admin',
    'terms',
    'www',
  };

  static final RegExp _pattern = RegExp(r'^[a-z0-9]+(?:-[a-z0-9]+)*$');

  static String normalize(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');

  static String? validationError(String value) {
    if (value.length < minLength || value.length > maxLength) {
      return 'Slug must be $minLength–$maxLength characters.';
    }
    if (!_pattern.hasMatch(value)) {
      return 'Use lowercase letters, numbers, and single hyphens only.';
    }
    if (reserved.contains(value)) return 'This slug is reserved.';
    return null;
  }

  static bool isValid(String value) => validationError(value) == null;
}

class HostnameClassification {
  const HostnameClassification({
    required this.surface,
    required this.hostname,
    this.communitySlug,
  });

  final WebSurface surface;
  final String hostname;
  final String? communitySlug;
}

class WebHostnameParser {
  const WebHostnameParser._();

  static const String productionDomain = 'hominode.com';

  static HostnameClassification classify(
    String rawHostname, {
    String path = '/',
  }) {
    final hostname = rawHostname.trim().toLowerCase().replaceFirst(
      RegExp(r'\.$'),
      '',
    );
    if (hostname == 'localhost' ||
        hostname == '127.0.0.1' ||
        hostname == '::1') {
      return HostnameClassification(
        surface: WebSurface.localDevelopment,
        hostname: hostname,
      );
    }
    if (hostname == 'www.$productionDomain') {
      return HostnameClassification(
        surface: WebSurface.marketing,
        hostname: hostname,
      );
    }
    if (hostname == 'admin.$productionDomain') {
      return HostnameClassification(
        surface: WebSurface.admin,
        hostname: hostname,
      );
    }

    if (hostname == productionDomain) {
      final segments = Uri(path: path).pathSegments
          .where((segment) => segment.isNotEmpty)
          .toList(growable: false);
      if (segments.isEmpty ||
          CommunitySlugPolicy.reserved.contains(segments.first)) {
        return HostnameClassification(
          surface: WebSurface.marketing,
          hostname: hostname,
        );
      }
      final slug = segments.first;
      if (CommunitySlugPolicy.isValid(slug)) {
        return HostnameClassification(
          surface: WebSurface.residentCommunity,
          hostname: hostname,
          communitySlug: slug,
        );
      }
    }
    return HostnameClassification(
      surface: WebSurface.invalid,
      hostname: hostname,
    );
  }
}

class HostnameCommunity {
  const HostnameCommunity({
    required this.communityId,
    required this.slug,
    required this.name,
  });

  final String communityId;
  final String slug;
  final String name;
}

class WebHostContext {
  const WebHostContext({required this.classification, this.community});

  static const String invalidResidentPath = '/__invalid_resident_path__';

  final HostnameClassification classification;
  final HostnameCommunity? community;

  bool get isResidentSurface =>
      classification.surface == WebSurface.residentCommunity ||
      (classification.surface == WebSurface.localDevelopment &&
          community != null);

  String internalPathFor(String externalPath) {
    if (!isResidentSurface ||
        classification.surface == WebSurface.localDevelopment) {
      return _normalizedPath(externalPath);
    }
    final slug = community?.slug;
    final segments = Uri(path: externalPath).pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (slug == null || segments.isEmpty || segments.first != slug) {
      return invalidResidentPath;
    }
    if (segments.length == 1) return '/resident';
    return '/${segments.skip(1).join('/')}';
  }

  String externalPathFor(String internalPath) {
    final normalized = _normalizedPath(internalPath);
    if (!isResidentSurface ||
        classification.surface == WebSurface.localDevelopment) {
      return normalized;
    }
    final slug = community!.slug;
    if (normalized == '/resident') return '/$slug/';
    if (normalized.startsWith('/resident/')) return '/$slug$normalized';
    if (normalized == '/login') return '/$slug/login';
    return '/$slug/';
  }

  static String _normalizedPath(String value) {
    final path = Uri.parse(value).path;
    return path.isEmpty ? '/' : path;
  }
}

class WebHostScope extends InheritedWidget {
  const WebHostScope({
    super.key,
    required this.hostContext,
    required super.child,
  });

  final WebHostContext hostContext;

  static WebHostContext? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<WebHostScope>()?.hostContext;

  @override
  bool updateShouldNotify(WebHostScope oldWidget) =>
      hostContext != oldWidget.hostContext;
}

class WebHostResolutionException implements Exception {
  const WebHostResolutionException(this.message);

  final String message;

  @override
  String toString() => message;
}

class WebHostResolver {
  WebHostResolver({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static const String _developmentSlug = String.fromEnvironment(
    'HOMINODE_DEV_COMMUNITY_SLUG',
  );

  final FirebaseFunctions _functions;

  Future<WebHostContext> resolve(Uri uri) async {
    final classification = WebHostnameParser.classify(uri.host, path: uri.path);
    String? slug = classification.communitySlug;

    if (classification.surface == WebSurface.localDevelopment &&
        kDebugMode &&
        _developmentSlug.isNotEmpty) {
      slug = _developmentSlug;
      final error = CommunitySlugPolicy.validationError(slug);
      if (error != null) {
        throw WebHostResolutionException(
          'Invalid HOMINODE_DEV_COMMUNITY_SLUG: $error',
        );
      }
    }

    if (slug == null) return WebHostContext(classification: classification);

    late final HttpsCallableResult<Map<String, dynamic>> result;
    try {
      result = await _functions
          .httpsCallable('resolveResidentCommunity')
          .call<Map<String, dynamic>>({'slug': slug});
    } on FirebaseFunctionsException catch (error) {
      if (error.code == 'not-found') {
        throw const WebHostResolutionException('Community not found.');
      }
      throw const WebHostResolutionException(
        'This community is currently unavailable.',
      );
    }

    final data = Map<String, dynamic>.from(result.data);
    final communityId = data['communityId']?.toString().trim() ?? '';
    final resolvedSlug = data['slug']?.toString().trim() ?? '';
    final name = data['name']?.toString().trim() ?? '';
    if (communityId.isEmpty || resolvedSlug != slug || name.isEmpty) {
      throw const WebHostResolutionException(
        'This community is currently unavailable.',
      );
    }
    return WebHostContext(
      classification: classification,
      community: HostnameCommunity(
        communityId: communityId,
        slug: resolvedSlug,
        name: name,
      ),
    );
  }
}
