import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hominode_storage/hominode_storage.dart';
import '../services/admin_tenant_context.dart';
import '../services/firebase_image_upload_service.dart';
import 'private_apartment_image.dart';

/// Existing attachment action, backed by the authorized complaint record.
class ComplaintAttachments extends StatefulWidget {
  const ComplaintAttachments({
    super.key,
    required this.complaintId,
    this.records,
    this.transport,
    this.scope,
    this.sessionChanges,
    this.tokenChanges,
  });
  final String complaintId;
  final Stream<Map<String, dynamic>?>? records;
  final FirebaseImageUploadService? transport;
  final String? Function()? scope;
  final Listenable? sessionChanges;
  final Stream<Object?>? tokenChanges;
  @override
  State<ComplaintAttachments> createState() => _ComplaintAttachmentsState();
}

class _ComplaintAttachmentsState extends State<ComplaintAttachments> {
  late final _transport = widget.transport ?? FirebaseImageUploadService();
  late final _sessions = widget.sessionChanges ?? AdminTenantContext.instance;
  late final _cache = ApartmentImageCache(
    read: _transport.read,
    revalidate: _transport.authorizeRead,
    scope: _scope,
  );
  late Stream<Map<String, dynamic>?> _records;
  StreamSubscription<Object?>? _tokens;
  int _epoch = 0;
  bool _authFailed = false;

  String? _scope() {
    if (widget.scope != null) return widget.scope!();
    final user = FirebaseAuth.instance.currentUser;
    final tenant = AdminTenantContext.instance;
    if (user == null || tenant.adminUid != user.uid) return null;
    try {
      final community = tenant.requireCommunityId();
      return '${user.uid}/$community';
    } on StateError {
      return null;
    }
  }

  void _watch() {
    _records =
        widget.records ??
        FirebaseFirestore.instance
            .collection('complaints')
            .doc(widget.complaintId)
            .snapshots()
            .map((snapshot) => snapshot.data());
  }

  @override
  void initState() {
    super.initState();
    _watch();
    _sessions.addListener(_invalidate);
    _tokens = (widget.tokenChanges ?? FirebaseAuth.instance.idTokenChanges())
        .listen(
          (_) {
            _authFailed = false;
            _invalidate();
          },
          onError: (Object _) {
            _authFailed = true;
            _invalidate();
          },
        );
  }

  void _invalidate() {
    _cache.clear();
    if (mounted) setState(() => _epoch++);
  }

  @override
  void dispose() {
    _sessions.removeListener(_invalidate);
    _tokens?.cancel();
    _cache.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _authFailed ? null : _scope();
    if (scope == null) return const Text('Sign in to view attachments.');
    return StreamBuilder<Map<String, dynamic>?>(
      stream: _records,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Attachments could not be loaded.'),
              TextButton(
                onPressed: () => setState(_watch),
                child: const Text('Retry'),
              ),
            ],
          );
        }
        if (!snapshot.hasData) {
          return snapshot.connectionState == ConnectionState.waiting
              ? const Center(child: CircularProgressIndicator())
              : const Text('No attachments.');
        }
        final data = snapshot.data!;
        if (!scope.endsWith('/${data['communityId']}')) {
          return const Text('Attachments are unavailable.');
        }
        final references = <String>{
          if (data['imageUrl'] is String &&
              (data['imageUrl'] as String).isNotEmpty)
            data['imageUrl'] as String,
          if (data['imageUrls'] is List)
            ...(data['imageUrls'] as List).whereType<String>(),
        }.toList();
        if (references.isEmpty) return const Text('No attachments.');
        final assets = data['managedImageAssets'];
        // This widget is displayed inside the complaint detail's
        // SingleChildScrollView. Keep the attachment list in that scroll
        // rather than asking a nested viewport to expand to infinite height.
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: references.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final reference = references[index];
            if (reference.startsWith('hominode-image:')) {
              try {
                final raw = assets is List
                    ? assets
                          .whereType<Map>()
                          .where(
                            (asset) =>
                                'hominode-image:${asset['assetId']}' ==
                                reference,
                          )
                          .single
                    : null;
                if (raw == null) throw const FormatException();
                final asset = StorageImageAsset.fromMap(
                  Map<String, dynamic>.from(raw),
                );
                if (asset.feature != 'complaints' ||
                    asset.resourceId != widget.complaintId) {
                  throw const FormatException();
                }
                return PrivateApartmentImage(
                  key: ValueKey('$scope/$_epoch/$reference'),
                  asset: asset,
                  cache: _cache,
                );
              } catch (_) {
                return const Text('Photo unavailable.');
              }
            }
            final uri = Uri.tryParse(reference);
            if (uri == null ||
                !{'http', 'https'}.contains(uri.scheme) ||
                uri.host.isEmpty) {
              return const Text('Photo unavailable.');
            }
            return Image.network(
              reference,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => const Text('Photo unavailable.'),
            );
          },
        );
      },
    );
  }
}
