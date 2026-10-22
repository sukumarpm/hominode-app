import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:hominode_storage/hominode_storage.dart';
import 'firebase_image_upload_service.dart';
import 'resident_image_operations.dart';

class PrivateImageData {
  PrivateImageData(this.asset, this.bytes);
  final StorageImageAsset asset;
  final Uint8List bytes;
}

/// Session-scoped, serialized, byte-bounded LRU. No URLs or disk cache.
class ResidentPrivateImageStore extends ChangeNotifier {
  ResidentPrivateImageStore({
    required this.call,
    required this.scope,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now {
    _identity = scope();
  }
  final ImageCallable call;
  final String? Function() scope;
  final DateTime Function() _now;
  final _cache = <String, (PrivateImageData, DateTime)>{};
  Future<void> _queue = Future.value();
  int epoch = 0, _bytes = 0;
  String? _identity;
  static const maxBytes = 20 * 1024 * 1024, maxEntries = 3;
  static const lifetime = Duration(seconds: 60);
  final _providers = <Object>{};
  void track(Object key) {
    _providers.add(key);
    if (_providers.length > 1000) {
      PaintingBinding.instance.imageCache.evict(_providers.first);
      _providers.remove(_providers.first);
    }
  }

  void invalidate() {
    epoch++;
    _cache.clear();
    _bytes = 0;
    _identity = scope();
    for (final key in _providers) {
      PaintingBinding.instance.imageCache.evict(key);
    }
    _providers.clear();
    notifyListeners();
  }

  Future<PrivateImageData> load(
    String reference, {
    PrivateImageData? retained,
    StorageImageAsset? knownAsset,
    bool refresh = false,
    bool Function()? stillNeeded,
  }) {
    if (_identity != scope()) {
      invalidate();
    }
    final identity = scope(), version = epoch;
    final future = _queue.then((_) async {
      void check() {
        if (identity == null ||
            scope() != identity ||
            epoch != version ||
            (stillNeeded != null && !stillNeeded())) {
          throw StateError('Private image access changed.');
        }
      }

      check();
      final id = reference.startsWith(privateImagePrefix)
          ? reference.substring(privateImagePrefix.length)
          : '';
      if (!RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
      ).hasMatch(id)) {
        throw const FormatException('Invalid private image reference.');
      }
      final cached = _cache.remove(reference);
      if (cached != null) {
        _bytes -= cached.$1.bytes.length;
      }
      if (!refresh &&
          cached != null &&
          _now().difference(cached.$2) < lifetime) {
        _cache[reference] = cached;
        _bytes += cached.$1.bytes.length;
        return cached.$1;
      }
      final previous = cached?.$1 ?? retained;
      final known = previous?.asset ?? knownAsset;
      final response = await call('readStorageImage', {
        'assetId': id,
        if (known != null) ...{
          'knownAssetId': known.assetId,
          'knownGeneration': known.generation,
        },
      }).timeout(const Duration(seconds: 60));
      check();
      final asset = StorageImageAsset.fromMap(
        Map<String, dynamic>.from(response['asset'] as Map),
      );
      if (asset.state != 'ready' ||
          response['assetId'] != asset.assetId ||
          response['generation'] != asset.generation ||
          response['size'] != asset.size ||
          response['contentType'] != asset.contentType ||
          !identity!.endsWith('/${asset.communityId}') ||
          (asset.assetId != id &&
              (asset.feature != 'profile' ||
                  response['redirectedFrom'] != id))) {
        throw const FormatException('Invalid private image response.');
      }
      final PrivateImageData result;
      if (response['notModified'] == true) {
        if (known == null ||
            known.assetId != asset.assetId ||
            known.generation != asset.generation) {
          throw const FormatException('Invalid cached image response.');
        }
        // A visible decoded frame can be reauthorized after its encoded buffer
        // was evicted. Do not download or retain another full-size byte array.
        if (previous == null) {
          return PrivateImageData(asset, Uint8List(0));
        }
        result = previous;
      } else {
        final encoded = response['base64'];
        if (encoded is! String ||
            encoded.length > ((StorageImageAsset.maxBytes + 2) ~/ 3) * 4) {
          throw const FormatException('Invalid private image data.');
        }
        final bytes = base64Decode(encoded);
        if (bytes.length != asset.size) {
          throw const FormatException('Invalid private image size.');
        }
        result = PrivateImageData(asset, bytes);
      }
      while (_cache.isNotEmpty &&
          (_cache.length >= maxEntries ||
              _bytes + result.bytes.length > maxBytes)) {
        _bytes -= _cache.remove(_cache.keys.first)!.$1.bytes.length;
      }
      _cache[reference] = (result, _now());
      _bytes += result.bytes.length;
      return result;
    });
    _queue = future.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return future;
  }
}

class ResidentPrivateImages {
  static ResidentPrivateImageStore? _store;
  static String? _selectedCommunity;
  static ResidentPrivateImageStore get store => _store ??= _production();
  static void selectCommunity(String? community) {
    _selectedCommunity = community;
    _store?.invalidate();
  }

  @visibleForTesting
  static void install(ResidentPrivateImageStore? value) {
    _store?.invalidate();
    _store = value;
  }

  static ResidentPrivateImageStore _production() {
    String? uid, community;
    var active = false;
    String? profileFingerprint;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? profile;
    final transport = FirebaseImageUploadService();
    final store = ResidentPrivateImageStore(
      call: transport.call,
      scope: () =>
          active &&
              uid != null &&
              community != null &&
              community == _selectedCommunity
          ? '$uid/$community'
          : null,
    );
    FirebaseAuth.instance.idTokenChanges().listen((user) {
      profileFingerprint = null;
      uid = user?.uid;
      community = null;
      active = false;
      store.invalidate();
      profile?.cancel();
      if (user != null) {
        profile = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .snapshots()
            .listen(
              (snapshot) {
                if (FirebaseAuth.instance.currentUser?.uid != user.uid) {
                  return;
                }
                final data = snapshot.data();
                const authorizationFields = [
                  'uid',
                  'phoneNumber',
                  'role',
                  'communityId',
                  'buildingId',
                  'flatId',
                  'isActive',
                  'approvalStatus',
                  'status',
                  'residentType',
                  'ownershipType',
                  'declaredResidentType',
                  'identityVerified',
                  'identityVerificationStatus',
                ];
                final assets = data?['managedImageAssets'];
                final nextFingerprint = [
                  for (final field in authorizationFields) data?[field],
                  assets is List
                      ? assets
                            .map(
                              (asset) => asset is Map
                                  ? [
                                      asset['assetId'],
                                      asset['generation'],
                                      asset['sha256'],
                                      asset['communityId'],
                                      asset['ownerId'],
                                      asset['resourceId'],
                                      asset['state'],
                                    ]
                                  : 'invalid',
                            )
                            .toList()
                      : assets == null
                      ? null
                      : 'invalid',
                ].toString();
                if (profileFingerprint == nextFingerprint) return;
                profileFingerprint = nextFingerprint;
                community = data?['communityId'] as String?;
                active =
                    data?['uid'] == user.uid &&
                    data?['role'] == 'resident' &&
                    data?['isActive'] == true &&
                    data?['approvalStatus'] == 'approved';
                store.invalidate();
              },
              onError: (Object _) {
                if (FirebaseAuth.instance.currentUser?.uid != user.uid) return;
                profileFingerprint = null;
                active = false;
                store.invalidate();
              },
            );
      }
    });
    return store;
  }
}

bool isPrivateResidentImageReference(String value) =>
    value.startsWith(privateImagePrefix);

ImageProvider residentImageProvider(String reference) =>
    reference.startsWith(privateImagePrefix)
    ? _ResidentPrivateImageProvider(reference, ResidentPrivateImages.store)
    : NetworkImage(reference);

class _PrivateKey {
  const _PrivateKey(this.reference, this.store, this.epoch, this.scope);
  final String reference;
  final ResidentPrivateImageStore store;
  final int epoch;
  final String? scope;
  @override
  bool operator ==(Object other) =>
      other is _PrivateKey &&
      reference == other.reference &&
      store == other.store &&
      epoch == other.epoch &&
      scope == other.scope;
  @override
  int get hashCode => Object.hash(reference, store, epoch, scope);
  @override
  String toString() => 'Private resident image';
}

class _ResidentPrivateImageProvider extends ImageProvider<_PrivateKey> {
  const _ResidentPrivateImageProvider(this.reference, this.store);
  final String reference;
  final ResidentPrivateImageStore store;
  @override
  Future<_PrivateKey> obtainKey(ImageConfiguration configuration) {
    final key = _PrivateKey(reference, store, store.epoch, store.scope());
    store.track(key);
    return SynchronousFuture(key);
  }

  @override
  ImageStreamCompleter loadImage(
    _PrivateKey key,
    ImageDecoderCallback decode,
  ) => _PrivateCompleter(key, decode);
  @override
  String toString() => 'Private resident image provider';
}

class _PrivateCompleter extends ImageStreamCompleter {
  _PrivateCompleter(this.key, this.decode) {
    addOnLastListenerRemovedCallback(_stop);
  }
  final _PrivateKey key;
  late int _activeEpoch = key.store.epoch;
  late String? _activeScope = key.store.scope();
  final ImageDecoderCallback decode;
  StorageImageAsset? _asset;
  bool _hasFrame = false;
  ui.Codec? _codec;
  ui.Image? _blank;
  Timer? _frameTimer, _authTimer;
  bool _running = false;
  int _request = 0, _frame = 0;
  bool get _valid =>
      key.store.epoch == _activeEpoch &&
      key.store.scope() == _activeScope &&
      _activeScope != null;
  final _quietListeners = <ImageStreamListener, (ImageStreamListener, int)>{};
  @override
  void addListener(ImageStreamListener listener) {
    // DecorationImage/CircleAvatar have no error builder. Expected access/file
    // failures clear their pixels and remain quiet; explicit image error
    // builders still receive the failure and render their existing fallback.
    var effective = listener;
    if (listener.onError == null) {
      final previous = _quietListeners[listener];
      effective =
          previous?.$1 ??
          ImageStreamListener(
            listener.onImage,
            onChunk: listener.onChunk,
            onError: (Object _, StackTrace? __) {},
          );
      _quietListeners[listener] = (effective, (previous?.$2 ?? 0) + 1);
    }
    super.addListener(effective);
    if (!_running) {
      _running = true;
      key.store.addListener(_onScopeChanged);
      scheduleMicrotask(() {
        if (hasListeners && _running) {
          unawaited(_load());
        }
      });
    }
  }

  @override
  void removeListener(ImageStreamListener listener) {
    final previous = _quietListeners[listener];
    if (previous != null) {
      if (previous.$2 == 1) {
        _quietListeners.remove(listener);
      } else {
        _quietListeners[listener] = (previous.$1, previous.$2 - 1);
      }
      super.removeListener(previous.$1);
    } else {
      super.removeListener(listener);
    }
  }

  void _stop() {
    _running = false;
    _request++;
    _frameTimer?.cancel();
    _authTimer?.cancel();
    _codec?.dispose();
    _codec = null;
    _blank?.dispose();
    _blank = null;
    key.store.removeListener(_onScopeChanged);
  }

  void _onScopeChanged() {
    _invalidate();
    _activeEpoch = key.store.epoch;
    _activeScope = key.store.scope();
    if (hasListeners && _activeScope != null) {
      unawaited(_load());
    }
  }

  void _invalidate() {
    _request++;
    _frameTimer?.cancel();
    _authTimer?.cancel();
    _codec?.dispose();
    _codec = null;
    _asset = null;
    _hasFrame = false;
    if (hasListeners && _blank != null) {
      setImage(ImageInfo(image: _blank!.clone()));
    }
    if (hasListeners) {
      reportError(
        exception: StateError('Private image access changed.'),
        silent: true,
      );
    }
  }

  Future<void> _load({bool refresh = false}) async {
    final request = ++_request;
    try {
      if (!_valid) {
        throw StateError('Private image access changed.');
      }
      if (_blank == null) {
        final recorder = ui.PictureRecorder();
        ui.Canvas(recorder);
        final picture = recorder.endRecording();
        _blank = await picture.toImage(1, 1);
        picture.dispose();
      }
      var result = await key.store.load(
        key.reference,
        knownAsset: _hasFrame ? _asset : null,
        refresh: refresh,
        stillNeeded: () =>
            hasListeners && _running && request == _request && _valid,
      );
      if (!hasListeners || request != _request || !_valid) {
        return;
      }
      final changed =
          _asset?.assetId != result.asset.assetId ||
          _asset?.generation != result.asset.generation;
      _asset = result.asset;
      if (changed || !_hasFrame) {
        if (result.bytes.isEmpty) {
          result = await key.store.load(key.reference);
        }
        if (!hasListeners || request != _request || !_valid) {
          return;
        }
        _frameTimer?.cancel();
        _codec?.dispose();
        final buffer = await ui.ImmutableBuffer.fromUint8List(result.bytes);
        final codec = await decode(
          buffer,
          getTargetSize: (width, height) {
            final maximum = width > height ? width : height;
            if (maximum <= 1024) {
              return ui.TargetImageSize(width: width, height: height);
            }
            return ui.TargetImageSize(
              width: (width * 1024 / maximum).round().clamp(1, 1024),
              height: (height * 1024 / maximum).round().clamp(1, 1024),
            );
          },
        );
        if (!hasListeners || request != _request || !_valid) {
          codec.dispose();
          return;
        }
        _codec = codec;
        _frame = 0;
        await _nextFrame(request);
      }
      if (!changed &&
          _codec != null &&
          _codec!.frameCount > 1 &&
          (_codec!.repetitionCount < 0 ||
              _frame < _codec!.frameCount * (_codec!.repetitionCount + 1))) {
        _frameTimer?.cancel();
        await _nextFrame(request);
      }
      _authTimer?.cancel();
      _authTimer = Timer(
        ResidentPrivateImageStore.lifetime,
        () => unawaited(_load(refresh: true)),
      );
    } catch (_) {
      if (hasListeners && request == _request) {
        _invalidate();
      }
    }
  }

  Future<void> _nextFrame(int request) async {
    final codec = _codec;
    if (codec == null || !hasListeners || !_valid) {
      return;
    }
    try {
      final frame = await codec.getNextFrame();
      if (!hasListeners || request != _request || !_valid) {
        frame.image.dispose();
        return;
      }
      setImage(ImageInfo(image: frame.image));
      _hasFrame = true;
      _frame++;
      if (codec.frameCount == 1) {
        codec.dispose();
        _codec = null;
        return;
      }
      if (codec.frameCount > 1 &&
          (codec.repetitionCount < 0 ||
              _frame < codec.frameCount * (codec.repetitionCount + 1))) {
        _frameTimer = Timer(
          frame.duration,
          () => unawaited(_nextFrame(request)),
        );
      }
    } catch (_) {
      if (hasListeners && request == _request) {
        _invalidate();
      }
    }
  }
}
