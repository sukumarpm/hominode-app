import 'dart:async';
import 'package:hominode_storage/hominode_storage.dart';
import 'resident_image_operations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Result class for apartment images operations (Flow Function Pattern)
class ApartmentImagesResult {
  final bool success;
  final String? message;
  final List<String>? imageUrls;
  final String? errorCode;

  ApartmentImagesResult({
    required this.success,
    this.message,
    this.imageUrls,
    this.errorCode,
  });

  factory ApartmentImagesResult.success({
    String? message,
    List<String>? imageUrls,
  }) {
    return ApartmentImagesResult(
      success: true,
      message: message ?? 'Operation successful',
      imageUrls: imageUrls ?? [],
    );
  }

  factory ApartmentImagesResult.failure({
    required String message,
    String? errorCode,
  }) {
    return ApartmentImagesResult(
      success: false,
      message: message,
      errorCode: errorCode,
    );
  }
}

/// Apartment Images Service - Flow Function Pattern
/// Fetches apartment/building images from Firestore apartmentImages collection
class ApartmentImagesService {
  ApartmentImagesService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static String? imageReference(Map<String, dynamic> data) {
    if (PhotoOwnership.isVersioned(data) &&
        (data['imageAsset'] == null ||
            !PhotoOwnership.matches(
              data,
              data['communityId'],
              data['ownershipScope'],
              data['resourceId'],
              buildingId: data['buildingId'],
            )))
      throw const FormatException('Invalid scoped photo.');
    if (data['imageAsset'] != null) {
      final asset = StorageImageAsset.fromMap(
        Map<String, dynamic>.from(data['imageAsset'] as Map),
      );
      if ((PhotoOwnership.isVersioned(data) &&
              !PhotoOwnership.matches(
                asset.toMap(),
                data['communityId'],
                data['ownershipScope'],
                data['resourceId'],
                buildingId: data['buildingId'],
              )) ||
          asset.feature != 'apartment' ||
          asset.state != 'ready' ||
          (!PhotoOwnership.isVersioned(data) &&
              data['buildingId'] != null &&
              asset.resourceId != data['buildingId'])) {
        throw const FormatException('Invalid apartment image.');
      }
      return '$privateImagePrefix${asset.assetId}';
    }
    return data['imageUrl'] as String?;
  }

  /// Use exactly the Admin gallery records, scoped to the selected canonical
  /// community. A malformed or foreign asset cannot replace the local fallback.
  static List<String> communityReferences(
    Iterable<Map<String, dynamic>> records,
    String communityId,
  ) {
    final sorted = records
        .where(
          (data) =>
              !PhotoOwnership.isVersioned(data) &&
              data['communityId'] == communityId &&
              data['status'] == 'active',
        )
        .toList();
    DateTime created(Map<String, dynamic> data) =>
        data['createdAt'] is Timestamp
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.fromMillisecondsSinceEpoch(0);
    sorted.sort((a, b) => created(b).compareTo(created(a)));
    final references = <String>[];
    for (final data in sorted) {
      try {
        if (data['imageAsset'] is Map &&
            (data['imageAsset'] as Map)['communityId'] != communityId)
          continue;
        final reference = imageReference(data);
        if (reference != null && reference.isNotEmpty)
          references.add(reference);
      } catch (_) {
        continue;
      }
    }
    return references;
  }

  static List<String> scopedReferences(
    Iterable<Map<String, dynamic>> records,
    String community,
    String scope,
    String resource, {
    String? buildingId,
  }) {
    final sorted = records
        .where(
          (data) =>
              data['status'] == 'active' &&
              PhotoOwnership.matches(
                data,
                community,
                scope,
                resource,
                buildingId: buildingId,
              ),
        )
        .toList();
    sorted.sort(
      (a, b) => ((b['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0)
          .compareTo(
            (a['createdAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0,
          ),
    );
    return sorted
        .map(imageReference)
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList();
  }

  Stream<List<String>> streamCommunityImages(
    String communityId, {
    bool legacy = false,
    String ownershipScope = 'COMMUNITY',
  }) {
    late StreamController<List<String>> controller;
    StreamSubscription<User?>? authSubscription;
    StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
    profileSubscription;
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? imagesSubscription;
    var epoch = 0;
    void clear() {
      if (!controller.isClosed) controller.add([]);
    }

    Future<void> cancelImages() async {
      await imagesSubscription?.cancel();
      imagesSubscription = null;
    }

    controller = StreamController<List<String>>(
      onListen: () {
        authSubscription = _auth.idTokenChanges().listen(
          (user) async {
            final session = ++epoch;
            clear();
            await cancelImages();
            await profileSubscription?.cancel();
            if (user == null || session != epoch || controller.isClosed) return;
            profileSubscription = _firestore
                .collection('users')
                .doc(user.uid)
                .snapshots()
                .listen(
                  (profile) async {
                    final request = ++epoch;
                    clear();
                    await cancelImages();
                    final data = profile.data();
                    if (controller.isClosed ||
                        request != epoch ||
                        _auth.currentUser?.uid != user.uid)
                      return;
                    if (data?['communityId'] != communityId ||
                        data?['isActive'] != true ||
                        data?['approvalStatus'] != 'approved') {
                      controller.addError(
                        StateError('Photo access is unavailable.'),
                      );
                      return;
                    }
                    final building = data?['buildingId'] as String?;
                    final resource = ownershipScope == 'COMMUNITY'
                        ? communityId
                        : ownershipScope == 'UNIT'
                        ? (data?['flatId'] as String?)
                        : building;
                    if (!legacy && (resource == null || resource.isEmpty)) {
                      controller.addError(
                        StateError('Photo assignment is unavailable.'),
                      );
                      return;
                    }
                    Query<Map<String, dynamic>> query = _firestore.collection(
                      legacy ? 'apartmentImages' : 'apartmentImagesV2',
                    );
                    final fields = legacy
                        ? {'communityId': communityId, 'status': 'active'}
                        : PhotoOwnership.queryFields(
                            communityId,
                            ownershipScope,
                            resource!,
                            buildingId: building,
                          );
                    for (final entry in fields.entries) {
                      query = query.where(entry.key, isEqualTo: entry.value);
                    }
                    imagesSubscription = query.snapshots().listen(
                      (snapshot) {
                        if (!controller.isClosed &&
                            request == epoch &&
                            _auth.currentUser?.uid == user.uid) {
                          try {
                            controller.add(
                              legacy
                                  ? communityReferences(
                                      snapshot.docs.map((doc) => doc.data()),
                                      communityId,
                                    )
                                  : scopedReferences(
                                      snapshot.docs.map((doc) => doc.data()),
                                      communityId,
                                      ownershipScope,
                                      resource!,
                                      buildingId: building,
                                    ),
                            );
                          } catch (_) {
                            clear();
                            controller.addError(
                              StateError('Photo data is unavailable.'),
                            );
                          }
                        }
                      },
                      onError: (Object _) {
                        if (request == epoch) {
                          clear();
                          controller.addError(
                            StateError('Photo access could not be verified.'),
                          );
                        }
                      },
                    );
                  },
                  onError: (Object _) {
                    ++epoch;
                    clear();
                    unawaited(cancelImages());
                  },
                );
          },
          onError: (Object _) {
            ++epoch;
            clear();
            unawaited(cancelImages());
          },
        );
      },
      onCancel: () async {
        ++epoch;
        await authSubscription?.cancel();
        await profileSubscription?.cancel();
        await cancelImages();
      },
    );
    return controller.stream;
  }

  /// Get apartment images - Following flow function pattern
  /// Step 1: Validate authentication → Step 2: Query collection → Step 3: Extract URLs → Step 4: Return result
  Future<ApartmentImagesResult> getApartmentImages() async {
    try {
      final user = FirebaseAuth.instance.currentUser;

      if (user == null) {
        return ApartmentImagesResult(
          success: false,
          message: 'User not authenticated',
        );
      }

      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!userDoc.exists) {
        return ApartmentImagesResult(
          success: false,
          message: 'User profile not found',
        );
      }

      final userData = userDoc.data()!;
      final buildingId = userData['buildingId']?.toString();
      final communityId = userData['communityId']?.toString().trim();

      if (buildingId == null ||
          buildingId.isEmpty ||
          communityId == null ||
          communityId.isEmpty) {
        return ApartmentImagesResult(
          success: false,
          message: 'Building not assigned',
        );
      }

      final snapshot = await FirebaseFirestore.instance
          .collection('apartmentImages')
          .where('communityId', isEqualTo: communityId)
          .where('buildingId', isEqualTo: buildingId)
          .where('status', isEqualTo: 'active')
          .get();

      final imageUrls = snapshot.docs
          .map((doc) => imageReference(doc.data()))
          .whereType<String>()
          .where((url) => url.isNotEmpty)
          .toList();

      return ApartmentImagesResult(success: true, imageUrls: imageUrls);
    } catch (e) {
      return ApartmentImagesResult(
        success: false,
        message: 'Failed to fetch apartment images: $e',
      );
    }
  }

  /// Stream apartment images in real-time
  /// Following flow function pattern with real-time updates
  Stream<ApartmentImagesResult> streamApartmentImages() async* {
    final user = _auth.currentUser;
    if (user == null) {
      yield ApartmentImagesResult.failure(message: 'User not authenticated');
      return;
    }
    final userDoc = await _firestore.collection('users').doc(user.uid).get();
    final data = userDoc.data();
    final communityId = data?['communityId']?.toString().trim();
    final buildingId = data?['buildingId']?.toString().trim();
    if (communityId == null ||
        communityId.isEmpty ||
        buildingId == null ||
        buildingId.isEmpty) {
      yield ApartmentImagesResult.failure(
        message: 'Community or building not assigned',
      );
      return;
    }

    yield* _firestore
        .collection('apartmentImages')
        .where('communityId', isEqualTo: communityId)
        .where('buildingId', isEqualTo: buildingId)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) {
          try {
            if (snapshot.docs.isEmpty) {
              return ApartmentImagesResult.success(
                message: 'No apartment images available',
                imageUrls: [],
              );
            }

            final images = <String>[];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              final imageUrl = imageReference(data);

              if (imageUrl != null && imageUrl.isNotEmpty) {
                images.add(imageUrl);
              }
            }

            return ApartmentImagesResult.success(
              message: 'Apartment images received',
              imageUrls: images,
            );
          } catch (e) {
            return ApartmentImagesResult.failure(
              message: 'Stream error: $e',
              errorCode: 'STREAM_ERROR',
            );
          }
        });
  }
}
