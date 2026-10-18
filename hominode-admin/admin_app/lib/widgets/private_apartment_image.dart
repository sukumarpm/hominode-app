import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:hominode_storage/hominode_storage.dart';

/// Screen-owned, session-scoped LRU. Serial reads bound in-flight buffers too.
class ApartmentImageCache {
  ApartmentImageCache({
    required this.read,
    required this.scope,
    this.revalidate,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;
  final Future<Uint8List> Function(StorageImageAsset) read;
  final String? Function() scope;
  final Future<void> Function(StorageImageAsset)? revalidate;
  final DateTime Function() _now;
  final _entries = <String, (Uint8List, DateTime)>{};
  Future<void> _queue = Future.value();
  int _epoch = 0;
  int _bytes = 0;
  String? _scope;
  static const maxBytes = 20 * 1024 * 1024;
  static const maxEntries = 3;
  static const lifetime = Duration(seconds: 60);

  void clear() {
    _epoch++;
    _entries.clear();
    _bytes = 0;
    _scope = scope();
  }

  Future<Uint8List> load(StorageImageAsset asset, {Uint8List? retained}) {
    if (_scope != scope()) clear();
    final epoch = _epoch;
    final identity = scope();
    final key =
        '${asset.communityId}/${asset.ownerId}/${asset.assetId}/${asset.generation}';
    final result = _queue.then((_) async {
      void check() {
        if (epoch != _epoch ||
            identity == null ||
            scope() != identity ||
            !identity.endsWith('/${asset.communityId}')) {
          throw StateError('The private image session changed.');
        }
      }

      check();
      final cached = _entries.remove(key);
      if (cached != null) {
        _bytes -= cached.$1.length;
        if (_now().difference(cached.$2) < lifetime) {
          _entries[key] = cached;
          _bytes += cached.$1.length;
          return cached.$1;
        }
      }
      final reusable = cached?.$1 ?? retained;
      final Uint8List bytes;
      if (reusable != null && revalidate != null) {
        await revalidate!(asset);
        bytes = reusable;
      } else {
        bytes = await read(asset);
      }
      check();
      if (bytes.length != asset.size || bytes.length > 10 * 1024 * 1024) {
        throw const FormatException('Invalid private image size.');
      }
      while (_entries.isNotEmpty &&
          (_entries.length >= maxEntries || _bytes + bytes.length > maxBytes)) {
        _bytes -= _entries.remove(_entries.keys.first)!.$1.length;
      }
      _entries[key] = (bytes, _now());
      _bytes += bytes.length;
      return bytes;
    });
    _queue = result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }
}

class PrivateApartmentImage extends StatefulWidget {
  const PrivateApartmentImage({
    super.key,
    required this.asset,
    required this.cache,
  });
  final StorageImageAsset asset;
  final ApartmentImageCache cache;
  @override
  State<PrivateApartmentImage> createState() => _PrivateApartmentImageState();
}

class _PrivateApartmentImageState extends State<PrivateApartmentImage> {
  Uint8List? _bytes;
  MemoryImage? _provider;
  bool _failed = false;
  Timer? _timer;
  int _request = 0;
  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant PrivateApartmentImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.assetId != widget.asset.assetId ||
        oldWidget.asset.generation != widget.asset.generation ||
        oldWidget.cache != widget.cache) {
      unawaited(_evict());
      _bytes = null;
      _provider = null;
      _load();
    }
  }

  Future<void> _load() async {
    _timer?.cancel();
    final request = ++_request;
    if (mounted) {
      setState(() {
        _failed = false;
      });
    }
    try {
      final bytes = await widget.cache.load(widget.asset, retained: _bytes);
      if (!mounted || request != _request) return;
      await _evict();
      if (!mounted || request != _request) return;
      setState(() {
        _bytes = bytes;
        _provider = MemoryImage(bytes);
      });
      _timer = Timer(ApartmentImageCache.lifetime, () {
        if (mounted) _load();
      });
    } catch (_) {
      if (!mounted || request != _request) return;
      await _evict();
      if (mounted && request == _request) {
        setState(() {
          _bytes = null;
          _provider = null;
          _failed = true;
        });
      }
    }
  }

  Future<void> _evict() async {
    if (_provider != null) {
      await ResizeImage(
        _provider!,
        width: 1024,
        height: 1024,
        policy: ResizeImagePolicy.fit,
      ).evict();
    }
  }

  @override
  void dispose() {
    _request++;
    _timer?.cancel();
    unawaited(_evict());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return SizedBox(
        height: 200,
        child: Center(
          child: IconButton(
            tooltip: 'Retry image',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ),
      );
    }
    if (_bytes == null) {
      return const SizedBox(
        height: 200,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    return Image(
      image: ResizeImage(
        _provider!,
        width: 1024,
        height: 1024,
        policy: ResizeImagePolicy.fit,
      ),
      width: double.infinity,
      height: 200,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => const SizedBox(
        height: 200,
        child: Center(child: Icon(Icons.image_not_supported)),
      ),
    );
  }
}
