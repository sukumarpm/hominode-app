import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_app_check/firebase_app_check.dart';

const hominodeNotificationChannelId = 'hominode_high_importance';
const _installationPreferenceKey = 'hominode_notification_installation_id';

typedef HominodeNotificationTapHandler =
    Future<void> Function(HominodeNotificationPayload payload);

@pragma('vm:entry-point')
Future<void> hominodeFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }
  // A visible FCM notification is rendered by the OS. Parsing here rejects
  // malformed data-only messages without performing navigation in an isolate.
  HominodeNotificationPayload.tryParse(message.data);
}

@immutable
class HominodeNotificationPayload {
  const HominodeNotificationPayload({
    required this.type,
    required this.entityId,
    required this.communityId,
  });

  static const Set<String> _allowedKeys = {'type', 'entityId', 'communityId'};

  final String type;
  final String entityId;
  final String communityId;

  static HominodeNotificationPayload? tryParse(Map<String, dynamic> data) {
    if (data.keys.any((key) => !_allowedKeys.contains(key))) return null;
    final type = data['type']?.toString().trim() ?? '';
    final entityId = data['entityId']?.toString().trim() ?? '';
    final communityId = data['communityId']?.toString().trim() ?? '';
    if (type != 'notification' ||
        entityId.isEmpty ||
        entityId.length > 200 ||
        communityId.isEmpty ||
        communityId.length > 128) {
      return null;
    }
    return HominodeNotificationPayload(
      type: type,
      entityId: entityId,
      communityId: communityId,
    );
  }

  static HominodeNotificationPayload? tryParseJson(String? value) {
    if (value == null || value.isEmpty) return null;
    try {
      final decoded = jsonDecode(value);
      if (decoded is! Map) return null;
      return tryParse(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return null;
    }
  }

  Map<String, String> toJson() => {
    'type': type,
    'entityId': entityId,
    'communityId': communityId,
  };

  String get dedupeKey => '$type|$entityId|$communityId';
}

class HominodePushNotifications {
  HominodePushNotifications._();

  static final HominodePushNotifications instance =
      HominodePushNotifications._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseAuth _auth = FirebaseAuth.instance;
  late final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  StreamSubscription<RemoteMessage>? _foregroundSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<User?>? _authSubscription;
  HominodeNotificationTapHandler? _tapHandler;
  HominodeNotificationPayload? _pendingTap;
  String? _selectedCommunityId;
  String? _lastHandledTap;
  final Set<String> _shownForegroundMessages = <String>{};
  Future<void>? _activation;
  bool _initialized = false;
  bool _active = false;

  Future<void> initialize({
    required HominodeNotificationTapHandler onAuthorizedTap,
  }) async {
    _tapHandler = onAuthorizedTap;
    if (_initialized) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(
      hominodeFirebaseMessagingBackgroundHandler,
    );

    const initializationSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );
    await _localNotifications.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (response) {
        final payload = HominodeNotificationPayload.tryParseJson(
          response.payload,
        );
        if (payload != null) unawaited(_acceptTap(payload));
      },
    );

    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        hominodeNotificationChannelId,
        'Important notifications',
        description: 'Time-sensitive community and account notifications.',
        importance: Importance.high,
      );
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );
    _foregroundSubscription = FirebaseMessaging.onMessage.listen(
      _showForegroundNotification,
    );
    _openedSubscription = FirebaseMessaging.onMessageOpenedApp.listen((
      message,
    ) {
      final payload = HominodeNotificationPayload.tryParse(message.data);
      if (payload != null) unawaited(_acceptTap(payload));
    });
    _tokenSubscription = _messaging.onTokenRefresh.listen((token) {
      if (_active) unawaited(_registerToken(token));
    });
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user == null && _active) {
        _active = false;
        _selectedCommunityId = null;
        unawaited(_messaging.deleteToken());
      }
    });

    final localLaunch = await _localNotifications
        .getNotificationAppLaunchDetails();
    if (localLaunch?.didNotificationLaunchApp == true) {
      final payload = HominodeNotificationPayload.tryParseJson(
        localLaunch?.notificationResponse?.payload,
      );
      if (payload != null) _pendingTap = payload;
    }
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      final payload = HominodeNotificationPayload.tryParse(initialMessage.data);
      if (payload != null) _pendingTap = payload;
    }
  }

  Future<void> activate({String? selectedCommunityId}) async {
    _active = true;
    _selectedCommunityId = selectedCommunityId?.trim();
    final running = _activation;
    if (running != null) return running;
    final next = _activateInternal();
    _activation = next;
    try {
      await next;
    } finally {
      _activation = null;
    }
  }

  Future<void> _activateInternal() async {
    if (!_initialized || _auth.currentUser == null) return;
    try {
      await _requestPermission();
      if (Platform.isIOS) {
        for (var attempt = 0; attempt < 8; attempt++) {
          if (await _messaging.getAPNSToken() != null) break;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      final token = await _messaging.getToken();
      if (token != null && token.isNotEmpty) await _registerToken(token);
      await _drainPendingTap();
    } catch (error, stackTrace) {
      debugPrint('Notification activation failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _requestPermission() async {
    if (Platform.isAndroid) {
      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.requestNotificationsPermission();
    }
    await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<void> _registerToken(String token) async {
    if (!_active || _auth.currentUser == null) return;
    try {
      final installationId = await _installationId();
      final data = <String, dynamic>{
        'token': token,
        'installationId': installationId,
      };
      final selectedCommunityId = _selectedCommunityId;
      if (selectedCommunityId != null && selectedCommunityId.isNotEmpty) {
        data['selectedCommunityId'] = selectedCommunityId;
      }
      await _functions.httpsCallable('registerNotificationDevice').call(data);
    } catch (error, stackTrace) {
      debugPrint('Notification token registration failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> deactivateForLogout() async {
    _active = false;
    _pendingTap = null;

    try {
      final user = _auth.currentUser;

      if (user != null) {
        try {
          final idToken = await user.getIdToken(true);
          debugPrint(
            'Logout notification auth token available: '
            '${idToken?.isNotEmpty == true}',
          );

          final appCheckToken = await FirebaseAppCheck.instance.getToken(true);

          debugPrint(
            'Logout notification App Check token available: '
            '${appCheckToken?.isNotEmpty == true}',
          );
        } catch (error) {
          debugPrint('Logout notification token validation failed: $error');
        }

        await _functions.httpsCallable('unregisterNotificationDevice').call({
          'installationId': await _installationId(),
        });
      }
    } catch (error, stackTrace) {
      debugPrint('Notification device removal failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _selectedCommunityId = null;

      try {
        await _messaging.deleteToken();
      } catch (error) {
        debugPrint('Local FCM token deletion failed: $error');
      }
    }
  }

  Future<void> _showForegroundNotification(RemoteMessage message) async {
    final payload = HominodeNotificationPayload.tryParse(message.data);
    final notification = message.notification;
    if (!_active || payload == null || notification == null) return;
    final messageKey = message.messageId ?? payload.dedupeKey;
    if (!_shownForegroundMessages.add(messageKey)) return;
    if (_shownForegroundMessages.length > 100) {
      _shownForegroundMessages.remove(_shownForegroundMessages.first);
    }
    final id = messageKey.codeUnits.fold<int>(
      0,
      (value, element) => ((value * 31) + element) & 0x7fffffff,
    );
    await _localNotifications.show(
      id,
      notification.title ?? 'Hominode',
      notification.body ?? '',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          hominodeNotificationChannelId,
          'Important notifications',
          channelDescription:
              'Time-sensitive community and account notifications.',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: jsonEncode(payload.toJson()),
    );
  }

  Future<void> _acceptTap(HominodeNotificationPayload payload) async {
    _pendingTap = payload;
    try {
      await _drainPendingTap();
    } catch (error, stackTrace) {
      debugPrint('Notification tap authorization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> _drainPendingTap() async {
    final payload = _pendingTap;
    final handler = _tapHandler;
    if (!_active ||
        _auth.currentUser == null ||
        payload == null ||
        handler == null) {
      return;
    }
    if (_lastHandledTap == payload.dedupeKey) {
      _pendingTap = null;
      return;
    }
    await handler(payload);
    _pendingTap = null;
    _lastHandledTap = payload.dedupeKey;
  }

  Future<String> _installationId() async {
    final preferences = await SharedPreferences.getInstance();
    final existing = preferences.getString(_installationPreferenceKey);
    if (existing != null &&
        RegExp(r'^[A-Za-z0-9_-]{16,128}$').hasMatch(existing)) {
      return existing;
    }
    final random = Random.secure();
    final bytes = List<int>.generate(24, (_) => random.nextInt(256));
    final generated = base64UrlEncode(bytes).replaceAll('=', '');
    await preferences.setString(_installationPreferenceKey, generated);
    return generated;
  }

  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    await _openedSubscription?.cancel();
    await _tokenSubscription?.cancel();
    await _authSubscription?.cancel();
    _initialized = false;
  }
}
