import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/notification_models.dart';
import 'admin_service.dart';
import 'notification_firestore_service.dart';

class AmenityService {
  AmenityService({
    FirebaseFirestore? firestore,
    AdminService? adminService,
    FirebaseStorage? storage,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _adminService = adminService ?? AdminService(),
       _storage = storage;

  final FirebaseFirestore _firestore;
  final AdminService _adminService;
  final FirebaseStorage? _storage;

  FirebaseStorage get _resolvedStorage => _storage ?? FirebaseStorage.instance;
  late final NotificationFirestoreService _notificationService =
      NotificationFirestoreService();
  final String _amenitiesCollection = 'amenities';
  final String _bookingsCollection = 'bookings';

  // Get all amenities for admin
  Stream<List<AmenityModel>> getAmenities() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('AmenityService: Fetching amenities for admin: $adminId');
    return _firestore
        .collection(_amenitiesCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print('AmenityService: Found ${snapshot.docs.length} amenities');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return AmenityModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  static const _editableFields = {
    'name',
    'type',
    'description',
    'iconName',
    'imageUrl',
    'images',
    'isAvailable',
    'isFree',
    'pricingMode',
    'pricePerDay',
    'ownerPricePerDay',
    'tenantPricePerDay',
    'timeSlots',
    'bookingDurations',
    'maxCapacity',
    'allowMultipleBookings',
    'hasSubscriptionPackages',
    'subscriptionPackages',
  };

  static String? priceValidationError(String? text) {
    final value = double.tryParse(text?.trim() ?? '');
    return value == null || !value.isFinite || value < 0
        ? 'Enter a finite price of 0 or more'
        : null;
  }

  static String? imageUrlValidationError(String? text) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    return uri == null ||
            !{'http', 'https'}.contains(uri.scheme.toLowerCase()) ||
            uri.host.isEmpty ||
            RegExp(r'\s').hasMatch(value)
        ? 'Enter a valid http:// or https:// image URL'
        : null;
  }

  static num _price(dynamic value) {
    if (value is! num || !value.isFinite || value < 0) {
      throw ArgumentError('Price must be a finite number of 0 or more.');
    }
    return value;
  }

  static String _pricingMode(dynamic value) {
    if (value == 'free' || value == 'flat' || value == 'resident_type') {
      return value as String;
    }

    throw ArgumentError('pricingMode must be free, flat, or resident_type.');
  }

  static List<String> _strings(dynamic value, String field) {
    if (value is! List ||
        value.any((item) => item is! String || item.trim().isEmpty)) {
      throw ArgumentError('$field must contain only nonempty strings.');
    }
    return value.cast<String>().map((item) => item.trim()).toList();
  }

  static List<Map<String, dynamic>> _facilityImages(dynamic value) {
    if (value is! List) {
      throw ArgumentError('images must be a list.');
    }
    if (value.length > 6) {
      throw ArgumentError('A facility can have at most 6 images.');
    }

    return value.map<Map<String, dynamic>>((item) {
      if (item is! Map) {
        throw ArgumentError('Each facility image must be a map.');
      }

      final raw = Map<String, dynamic>.from(item);
      final url = raw['url'];
      final storagePath = raw['storagePath'];
      final name = raw['name'];

      if (url is! String || imageUrlValidationError(url) != null) {
        throw ArgumentError('Each facility image must contain a valid URL.');
      }
      if (storagePath is! String || storagePath.trim().isEmpty) {
        throw ArgumentError('Each managed facility image needs a storagePath.');
      }
      if (name != null && name is! String) {
        throw ArgumentError('Facility image name must be a string.');
      }

      return {
        'url': url.trim(),
        'storagePath': storagePath.trim(),
        if (name is String && name.trim().isNotEmpty) 'name': name.trim(),
      };
    }).toList();
  }

  static Map<String, dynamic> _facilityFields(Map<String, dynamic> input) {
    final fields = <String, dynamic>{};
    for (final entry in input.entries) {
      final key = entry.key;
      final value = entry.value;
      if (!_editableFields.contains(key)) {
        throw ArgumentError('Facility field is not editable: $key');
      }
      switch (key) {
        case 'name':
        case 'type':
          if (value is! String || value.trim().isEmpty) {
            throw ArgumentError('$key is required.');
          }
          fields[key] = value.trim();
        case 'description':
        case 'iconName':
        case 'imageUrl':
          if (value != null && value is! String) {
            throw ArgumentError('$key must be a string.');
          }
          final text = (value as String?)?.trim() ?? '';
          if (key == 'imageUrl' && imageUrlValidationError(text) != null) {
            throw ArgumentError(imageUrlValidationError(text));
          }
          fields[key] = text;
        case 'images':
          fields[key] = _facilityImages(value);
        case 'isFree':
        case 'isAvailable':
        case 'allowMultipleBookings':
        case 'hasSubscriptionPackages':
          if (value is! bool) throw ArgumentError('$key must be a boolean.');
          fields[key] = value;

        case 'pricingMode':
          fields[key] = _pricingMode(value);

        case 'pricePerDay':
        case 'ownerPricePerDay':
        case 'tenantPricePerDay':
          fields[key] = _price(value);
        case 'timeSlots':
        case 'bookingDurations':
          fields[key] = _strings(value, key);
          if (key == 'bookingDurations' && (fields[key] as List).isEmpty) {
            throw ArgumentError('Select at least one booking duration.');
          }
        case 'maxCapacity':
          if (value is! int || value <= 0) {
            throw ArgumentError('Capacity must be a positive integer.');
          }
          fields[key] = value;
        case 'subscriptionPackages':
          if (value is! Map) throw ArgumentError('Packages must be a map.');
          final packages = <String, num>{};
          for (final package in value.entries) {
            if (package.key is! String ||
                (package.key as String).trim().isEmpty) {
              throw ArgumentError('Package names must not be empty.');
            }
            packages[package.key as String] = _price(package.value);
          }
          fields[key] = packages;
      }
    }
    return fields;
  }

  void _checkCurrentCommunity(String communityId) {
    if (_adminService.getCurrentAdminId() == null ||
        _adminService.requireCurrentCommunityId() != communityId) {
      throw StateError('Your selected community changed. Reopen the facility.');
    }
  }

  Future<String> addAmenity({
    required String name,
    required String type,
    required bool isFree,
    required String buildingId,
    bool isAvailable = true,
    double? pricePerDay,
    String? pricingMode,
    double? ownerPricePerDay,
    double? tenantPricePerDay,
    String? description,
    String? iconName,
    String? imageUrl,
    List<XFile>? imageFiles,
    List<String>? timeSlots,
    int? maxCapacity,
    bool? allowMultipleBookings,
    List<String>? bookingDurations,
    bool? hasSubscriptionPackages,
    Map<String, double>? subscriptionPackages,
  }) async {
    final communityId = _adminService.requireCurrentCommunityId();
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) throw StateError('Admin not logged in');
    final id = buildingId.trim();
    if (id.isEmpty || id.contains('/')) {
      throw ArgumentError('Select a valid building.');
    }
    final mode = _pricingMode(pricingMode ?? (isFree ? 'free' : 'flat'));

    if ((mode == 'free') != isFree) {
      throw ArgumentError(
        'Facility pricing mode does not match its free/chargeable setting.',
      );
    }

    final input = <String, dynamic>{
      'name': name,
      'type': type,
      'isFree': isFree,
      'isAvailable': isAvailable,
      'pricingMode': mode,
      'pricePerDay': mode == 'flat' ? pricePerDay : 0,
      'description': description,
      'iconName': iconName,
      'imageUrl': imageUrl,
      'timeSlots': timeSlots ?? <String>[],
      'maxCapacity': maxCapacity ?? 1,
      'allowMultipleBookings': allowMultipleBookings ?? false,
      'bookingDurations': bookingDurations ?? ['1 hour'],
      'hasSubscriptionPackages': hasSubscriptionPackages ?? false,
      'subscriptionPackages': subscriptionPackages ?? <String, double>{},
    };

    if (mode == 'resident_type') {
      input['ownerPricePerDay'] = ownerPricePerDay;
      input['tenantPricePerDay'] = tenantPricePerDay;
    }

    final fields = _facilityFields(input);
    final building = (await _firestore.collection('buildings').doc(id).get())
        .data();
    if (building == null) throw StateError('Building no longer exists.');
    if (building['communityId'] != communityId) {
      throw StateError('Building is outside your selected community.');
    }
    final buildingName = [
      building['buildingName'],
      building['name'],
      id,
    ].whereType<String>().firstWhere((name) => name.trim().isNotEmpty).trim();
    final profile = await _adminService.getAdminProfile();
    _checkCurrentCommunity(communityId);
    final record = await _firestore.collection(_amenitiesCollection).add({
      ...fields,
      'buildingId': id,
      'buildingName': buildingName,
      'communityId': communityId,
      'adminId': adminId,
      'adminName': profile?['name'] ?? '',
      'adminEmail': profile?['email'] ?? '',
      'organization': profile?['organization'] ?? '',
      'authorId': adminId,
      'authorName': profile?['name'] ?? '',
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    final selectedImages = imageFiles ?? const <XFile>[];
    if (selectedImages.isNotEmpty) {
      try {
        await replaceAmenityImages(
          amenityId: record.id,
          images: selectedImages
              .map(AmenityImageDraft.file)
              .toList(growable: false),
        );
      } catch (_) {
        // The Storage rule requires the facility document to exist while
        // facility images are managed. replaceAmenityImages cleans up any
        // uploads it completed; remove the newly-created empty facility too.
        await record.delete();
        rethrow;
      }
    }

    return record.id;
  }

  // Only explicitly edited fields are written; tenant/building and legacy data
  // are never copied from a form into the update.
  Future<void> updateAmenity(
    String amenityId,
    Map<String, dynamic> updates,
  ) async {
    final communityId = _adminService.requireCurrentCommunityId();
    _checkCurrentCommunity(communityId);
    final record = _firestore.collection(_amenitiesCollection).doc(amenityId);
    final existing = (await record.get()).data();
    if (existing == null) throw StateError('Facility no longer exists.');
    if (existing['communityId'] != communityId) {
      throw StateError('Facility is outside your selected community.');
    }
    final fields = _facilityFields(updates);
    final pricingEdited = {
      'isFree',
      'pricingMode',
      'pricePerDay',
      'ownerPricePerDay',
      'tenantPricePerDay',
    }.any(fields.containsKey);

    if (pricingEdited) {
      final storedMode = existing['pricingMode'];

      final existingMode =
          storedMode == 'free' ||
              storedMode == 'flat' ||
              storedMode == 'resident_type'
          ? storedMode as String
          : existing['isFree'] == true
          ? 'free'
          : 'flat';

      var mode = fields.containsKey('pricingMode')
          ? _pricingMode(fields['pricingMode'])
          : existingMode;

      // Compatibility with existing Flutter callers which only change isFree.
      if (!fields.containsKey('pricingMode') && fields.containsKey('isFree')) {
        final requestedIsFree = fields['isFree'];

        if (requestedIsFree is! bool) {
          throw ArgumentError('isFree must be a boolean.');
        }

        if (requestedIsFree) {
          mode = 'free';
        } else if (existingMode == 'free') {
          mode = 'flat';
        }
      }

      final expectedIsFree = mode == 'free';

      if (fields.containsKey('isFree')) {
        final requestedIsFree = fields['isFree'];

        if (requestedIsFree is! bool) {
          throw ArgumentError('isFree must be a boolean.');
        }

        if (requestedIsFree != expectedIsFree) {
          throw ArgumentError(
            'Facility pricing mode does not match its free/chargeable setting.',
          );
        }
      }

      fields['pricingMode'] = mode;
      fields['isFree'] = expectedIsFree;

      if (mode == 'free') {
        fields['pricePerDay'] = 0;
      } else if (mode == 'flat') {
        fields['pricePerDay'] = _price(
          fields.containsKey('pricePerDay')
              ? fields['pricePerDay']
              : existing['pricePerDay'],
        );
      } else {
        fields['pricePerDay'] = 0;

        fields['ownerPricePerDay'] = _price(
          fields.containsKey('ownerPricePerDay')
              ? fields['ownerPricePerDay']
              : existing['ownerPricePerDay'],
        );

        fields['tenantPricePerDay'] = _price(
          fields.containsKey('tenantPricePerDay')
              ? fields['tenantPricePerDay']
              : existing['tenantPricePerDay'],
        );
      }
    }
    _checkCurrentCommunity(communityId);
    if (fields.isEmpty) return;
    await record.update({...fields, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<List<AmenityImageModel>> replaceAmenityImages({
    required String amenityId,
    required List<AmenityImageDraft> images,
  }) async {
    if (images.length > 6) {
      throw ArgumentError('A facility can have at most 6 images.');
    }

    final communityId = _adminService.requireCurrentCommunityId();
    _checkCurrentCommunity(communityId);

    final record = _firestore.collection(_amenitiesCollection).doc(amenityId);
    final existing = (await record.get()).data();
    if (existing == null) {
      throw StateError('Facility no longer exists.');
    }
    if (existing['communityId'] != communityId) {
      throw StateError('Facility is outside your selected community.');
    }

    final previousImages = AmenityImageModel.fromFirestoreList(
      existing['images'],
      legacyImageUrl: existing['imageUrl'],
    );

    final uploadedThisAttempt = <AmenityImageModel>[];
    final finalImages = <AmenityImageModel>[];

    try {
      for (var index = 0; index < images.length; index++) {
        final draft = images[index];

        if (draft.existingImage != null) {
          final image = draft.existingImage!;
          if (imageUrlValidationError(image.url) != null) {
            throw ArgumentError('Facility image URL is invalid.');
          }
          finalImages.add(image);
          continue;
        }

        final file = draft.newFile;
        if (file == null) {
          throw ArgumentError('Facility image selection is invalid.');
        }

        final uploaded = await _uploadAmenityImage(
          communityId: communityId,
          amenityId: amenityId,
          file: file,
          index: index,
        );
        uploadedThisAttempt.add(uploaded);
        finalImages.add(uploaded);
      }

      final imageMaps = finalImages
          .where((image) => image.storagePath?.isNotEmpty == true)
          .map((image) => image.toMap())
          .toList(growable: false);

      _checkCurrentCommunity(communityId);
      await record.update({
        'images': imageMaps,
        'imageUrl': finalImages.isEmpty ? '' : finalImages.first.url,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Only remove old managed Storage objects after Firestore has accepted
      // the new ordered gallery. Legacy imageUrl-only records have no path and
      // are therefore never deleted from Storage by this cleanup.
      final keptPaths = finalImages
          .map((image) => image.storagePath)
          .whereType<String>()
          .where((path) => path.isNotEmpty)
          .toSet();

      for (final oldImage in previousImages) {
        final path = oldImage.storagePath;
        if (path != null && path.isNotEmpty && !keptPaths.contains(path)) {
          await _deleteStoragePathQuietly(path);
        }
      }

      return finalImages;
    } catch (_) {
      for (final image in uploadedThisAttempt) {
        final path = image.storagePath;
        if (path != null && path.isNotEmpty) {
          await _deleteStoragePathQuietly(path);
        }
      }
      rethrow;
    }
  }

  Future<AmenityImageModel> _uploadAmenityImage({
    required String communityId,
    required String amenityId,
    required XFile file,
    required int index,
  }) async {
    final originalName = file.name.trim().isNotEmpty
        ? file.name.trim()
        : file.path.split(RegExp(r'[/\\]')).last;

    final extension = _supportedImageExtension(originalName);
    if (extension == null) {
      throw ArgumentError('Facility photos must be JPG, PNG, or WebP.');
    }

    final length = await file.length();
    if (length > 5 * 1024 * 1024) {
      throw ArgumentError('Each facility photo must be 5 MB or smaller.');
    }

    final bytes = await file.readAsBytes();
    if (bytes.length > 5 * 1024 * 1024) {
      throw ArgumentError('Each facility photo must be 5 MB or smaller.');
    }

    final stamp = DateTime.now().microsecondsSinceEpoch;
    final storageName = '${stamp}_$index.$extension';
    final storagePath = 'facility_images/$communityId/$amenityId/$storageName';
    final reference = _resolvedStorage.ref().child(storagePath);

    await reference.putData(
      bytes,
      SettableMetadata(contentType: _contentTypeForExtension(extension)),
    );

    final url = await reference.getDownloadURL();

    return AmenityImageModel(
      url: url,
      storagePath: storagePath,
      name: originalName,
    );
  }

  static String? _supportedImageExtension(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;

    final extension = name.substring(dot + 1).toLowerCase();
    switch (extension) {
      case 'jpg':
      case 'jpeg':
        return 'jpg';
      case 'png':
        return 'png';
      case 'webp':
        return 'webp';
      default:
        return null;
    }
  }

  static String _contentTypeForExtension(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      default:
        return 'image/jpeg';
    }
  }

  Future<void> _deleteStoragePathQuietly(String storagePath) async {
    try {
      await _resolvedStorage.ref().child(storagePath).delete();
    } on FirebaseException catch (error) {
      if (error.code != 'object-not-found') {
        debugPrint(
          'AmenityService: unable to delete facility image $storagePath: $error',
        );
      }
    } catch (error) {
      debugPrint(
        'AmenityService: unable to delete facility image $storagePath: $error',
      );
    }
  }

  // Delete amenity
  Future<void> deleteAmenity(String amenityId) async {
    try {
      final communityId = _adminService.requireCurrentCommunityId();
      _checkCurrentCommunity(communityId);

      final record = _firestore.collection(_amenitiesCollection).doc(amenityId);
      final existing = (await record.get()).data();
      if (existing == null) {
        throw StateError('Facility no longer exists.');
      }
      if (existing['communityId'] != communityId) {
        throw StateError('Facility is outside your selected community.');
      }

      final images = AmenityImageModel.fromFirestoreList(
        existing['images'],
        legacyImageUrl: existing['imageUrl'],
      );

      // Delete managed files first: the Storage rule requires the facility
      // Firestore document to still exist while deleting its images.
      for (final image in images) {
        final path = image.storagePath;
        if (path == null || path.isEmpty) continue;

        try {
          await _resolvedStorage.ref().child(path).delete();
        } on FirebaseException catch (error) {
          if (error.code != 'object-not-found') rethrow;
        }
      }

      _checkCurrentCommunity(communityId);
      await record.delete();
      print('AmenityService: Amenity deleted successfully');
    } catch (e) {
      print('AmenityService ERROR: Failed to delete amenity: $e');
      throw Exception('Failed to delete amenity: $e');
    }
  }

  // Get all bookings for admin filtered by adminId
  Stream<List<AmenityBookingModel>> getBookings() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('AmenityService getBookings: Fetching bookings for admin: $adminId');

    return _firestore
        .collection(_bookingsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          print(
            'AmenityService getBookings: Found ${snapshot.docs.length} bookings',
          );

          final bookings = snapshot.docs.map((doc) {
            return AmenityBookingModel.fromFirestore(doc.id, doc.data());
          }).toList();

          // Sort by booking date descending
          bookings.sort((a, b) {
            if (a.bookingDateTimestamp != null &&
                b.bookingDateTimestamp != null) {
              return b.bookingDateTimestamp!.compareTo(a.bookingDateTimestamp!);
            }
            return 0;
          });

          print(
            'AmenityService getBookings: Returning ${bookings.length} bookings',
          );
          return bookings;
        });
  }

  // Get pending bookings count
  Stream<int> getPendingBookingsCount() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value(0);

    return _firestore
        .collection(_bookingsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  // Approve booking
  Future<void> approveBooking(String bookingId) async {
    try {
      print('🔵 BOOKING APPROVAL: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Booking
      print('📋 STEP 2: Validating booking...');
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found');

      final bookingData = bookingDoc.data();
      final residentId = bookingData?['residentId'];
      final amenityName = bookingData?['amenityName'] ?? 'Amenity';
      final bookingDate = bookingData?['bookingDate'] ?? 'Unknown date';
      print('✅ STEP 2 PASSED');

      // STEP 3: Approve Booking
      print('📝 STEP 3: Approving booking...');
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'approved',
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Booking Approved',
            message:
                'Your booking for $amenityName on $bookingDate has been approved',
            type: NotificationType.event,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'bookingId': bookingId,
              'amenityName': amenityName,
              'bookingDate': bookingDate,
            },
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BOOKING APPROVAL: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to approve booking: $e');
    }
  }

  // Reject booking
  Future<void> rejectBooking(String bookingId, String? reason) async {
    try {
      print('🔵 BOOKING REJECTION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Booking
      print('📋 STEP 2: Validating booking...');
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found');

      final bookingData = bookingDoc.data();
      final residentId = bookingData?['residentId'];
      final amenityName = bookingData?['amenityName'] ?? 'Amenity';
      print('✅ STEP 2 PASSED');

      // STEP 3: Reject Booking
      print('📝 STEP 3: Rejecting booking...');
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'rejected',
        'rejectionReason': reason,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Booking Rejected',
            message:
                'Your booking for $amenityName has been rejected. Reason: ${reason ?? 'Not specified'}',
            type: NotificationType.event,
            priority: NotificationPriority.high,
            recipientId: residentId,
            metadata: {
              'bookingId': bookingId,
              'amenityName': amenityName,
              'reason': reason,
            },
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BOOKING REJECTION: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to reject booking: $e');
    }
  }

  // Cancel booking
  Future<void> cancelBooking(String bookingId) async {
    try {
      print('🔵 BOOKING CANCELLATION: Starting...');

      // STEP 1: Validate Admin
      print('🔐 STEP 1: Validating admin...');
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');
      print('✅ STEP 1 PASSED');

      // STEP 2: Validate Booking
      print('📋 STEP 2: Validating booking...');
      final bookingDoc = await _firestore
          .collection(_bookingsCollection)
          .doc(bookingId)
          .get();
      if (!bookingDoc.exists) throw Exception('Booking not found');

      final bookingData = bookingDoc.data();
      final residentId = bookingData?['residentId'];
      final amenityName = bookingData?['amenityName'] ?? 'Amenity';
      print('✅ STEP 2 PASSED');

      // STEP 3: Cancel Booking
      print('📝 STEP 3: Cancelling booking...');
      await _firestore.collection(_bookingsCollection).doc(bookingId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('✅ STEP 3 PASSED');

      // STEP 4: Notify Resident
      print('🔔 STEP 4: Notifying resident...');
      if (residentId != null) {
        try {
          await _notificationService.createNotification(
            title: 'Booking Cancelled',
            message: 'Your booking for $amenityName has been cancelled',
            type: NotificationType.event,
            priority: NotificationPriority.medium,
            recipientId: residentId,
            metadata: {'bookingId': bookingId, 'amenityName': amenityName},
          );
          print('✅ STEP 4 PASSED: Resident notified');
        } catch (notificationError) {
          print(
            '⚠️ STEP 4 WARNING: Failed to send notification: $notificationError',
          );
        }
      }

      print('✅ BOOKING CANCELLATION: COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      throw Exception('Failed to cancel booking: $e');
    }
  }

  // Check slot availability considering capacity
  Future<Map<String, dynamic>> checkSlotAvailability({
    required String amenityId,
    required String bookingDate,
    required String timeSlot,
  }) async {
    try {
      // Get amenity details
      final amenityDoc = await _firestore
          .collection(_amenitiesCollection)
          .doc(amenityId)
          .get();
      if (!amenityDoc.exists) {
        throw Exception('Amenity not found');
      }

      final amenityData = amenityDoc.data()!;
      final maxCapacity = amenityData['maxCapacity'] ?? 1;
      final allowMultiple = amenityData['allowMultipleBookings'] ?? false;

      // If multiple bookings not allowed, check if any booking exists
      if (!allowMultiple) {
        final existingBookings = await _firestore
            .collection(_bookingsCollection)
            .where('amenityId', isEqualTo: amenityId)
            .where('bookingDate', isEqualTo: bookingDate)
            .where('timeSlot', isEqualTo: timeSlot)
            .where('status', whereIn: ['pending', 'approved', 'confirmed'])
            .get();

        if (existingBookings.docs.isNotEmpty) {
          return {
            'available': false,
            'reason': 'This time slot is already booked',
            'currentBookings': existingBookings.docs.length,
            'maxCapacity': maxCapacity,
          };
        }

        return {
          'available': true,
          'currentBookings': 0,
          'maxCapacity': maxCapacity,
        };
      }

      // If multiple bookings allowed, check capacity
      final existingBookings = await _firestore
          .collection(_bookingsCollection)
          .where('amenityId', isEqualTo: amenityId)
          .where('bookingDate', isEqualTo: bookingDate)
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['pending', 'approved', 'confirmed'])
          .get();

      final currentBookings = existingBookings.docs.length;

      if (currentBookings >= maxCapacity) {
        return {
          'available': false,
          'reason': 'Maximum capacity reached ($maxCapacity/$maxCapacity)',
          'currentBookings': currentBookings,
          'maxCapacity': maxCapacity,
        };
      }

      return {
        'available': true,
        'currentBookings': currentBookings,
        'maxCapacity': maxCapacity,
        'spotsLeft': maxCapacity - currentBookings,
      };
    } catch (e) {
      print('AmenityService ERROR: Failed to check availability: $e');
      throw Exception('Failed to check availability: $e');
    }
  }

  // Get bookings count for a specific slot
  Future<int> getSlotBookingsCount({
    required String amenityId,
    required String bookingDate,
    required String timeSlot,
  }) async {
    try {
      final bookings = await _firestore
          .collection(_bookingsCollection)
          .where('amenityId', isEqualTo: amenityId)
          .where('bookingDate', isEqualTo: bookingDate)
          .where('timeSlot', isEqualTo: timeSlot)
          .where('status', whereIn: ['pending', 'approved', 'confirmed'])
          .get();

      return bookings.docs.length;
    } catch (e) {
      print('AmenityService ERROR: Failed to get bookings count: $e');
      return 0;
    }
  }

  // Get bookings by date range for calendar view
  Stream<List<AmenityBookingModel>> getBookingsByDateRange({
    required DateTime startDate,
    required DateTime endDate,
  }) {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    final startDateStr = _formatDate(startDate);
    final endDateStr = _formatDate(endDate);

    print(
      'AmenityService: Fetching bookings from $startDateStr to $endDateStr',
    );

    return _firestore
        .collection(_bookingsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('bookingDate', isGreaterThanOrEqualTo: startDateStr)
        .where('bookingDate', isLessThanOrEqualTo: endDateStr)
        .snapshots()
        .map((snapshot) {
          print(
            'AmenityService: Found ${snapshot.docs.length} bookings in date range',
          );
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return AmenityBookingModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  // Get bookings grouped by date for calendar filtered by adminId
  Future<Map<DateTime, List<AmenityBookingModel>>> getBookingsGroupedByDate({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return {};

    print(
      'AmenityService: Fetching bookings for admin: $adminId, date range: $startDate to $endDate',
    );

    try {
      // Fetch bookings filtered by adminId
      final snapshot = await _firestore
          .collection(_bookingsCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .get();

      print('AmenityService: Total bookings found: ${snapshot.docs.length}');

      final Map<DateTime, List<AmenityBookingModel>> groupedBookings = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();
        print('AmenityService: Processing booking ${doc.id}');

        final booking = AmenityBookingModel.fromFirestore(doc.id, data);

        // Get date from Timestamp 'date' field
        DateTime? bookingDate;

        if (data['date'] != null && data['date'] is Timestamp) {
          bookingDate = (data['date'] as Timestamp).toDate();
          print('AmenityService: Booking date: $bookingDate');
        }

        if (bookingDate != null) {
          // Check if date is in range
          if (bookingDate.isBefore(startDate) || bookingDate.isAfter(endDate)) {
            print('AmenityService: Date outside range, skipping');
            continue;
          }

          // Normalize to midnight
          final normalizedDate = DateTime(
            bookingDate.year,
            bookingDate.month,
            bookingDate.day,
          );

          print('AmenityService: Adding to date: $normalizedDate');

          if (!groupedBookings.containsKey(normalizedDate)) {
            groupedBookings[normalizedDate] = [];
          }
          groupedBookings[normalizedDate]!.add(booking);
        }
      }

      print(
        'AmenityService: Grouped ${groupedBookings.length} dates with bookings',
      );
      return groupedBookings;
    } catch (e, stackTrace) {
      print('AmenityService ERROR: $e');
      print('AmenityService ERROR Stack: $stackTrace');
      return {};
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

class AmenityImageModel {
  final String url;
  final String? storagePath;
  final String? name;

  const AmenityImageModel({required this.url, this.storagePath, this.name});

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      if (storagePath != null && storagePath!.isNotEmpty)
        'storagePath': storagePath,
      if (name != null && name!.isNotEmpty) 'name': name,
    };
  }

  static List<AmenityImageModel> fromFirestoreList(
    dynamic raw, {
    dynamic legacyImageUrl,
  }) {
    final images = <AmenityImageModel>[];

    if (raw is List) {
      for (final item in raw) {
        if (item is! Map) continue;

        final map = Map<String, dynamic>.from(item);
        final url = map['url'];
        if (url is! String ||
            AmenityService.imageUrlValidationError(url) != null) {
          continue;
        }

        final storagePath = map['storagePath'];
        final name = map['name'];

        images.add(
          AmenityImageModel(
            url: url.trim(),
            storagePath: storagePath is String && storagePath.trim().isNotEmpty
                ? storagePath.trim()
                : null,
            name: name is String && name.trim().isNotEmpty ? name.trim() : null,
          ),
        );

        if (images.length == 6) break;
      }
    }

    if (images.isNotEmpty) return images;

    if (legacyImageUrl is String &&
        AmenityService.imageUrlValidationError(legacyImageUrl) == null &&
        legacyImageUrl.trim().isNotEmpty) {
      return [AmenityImageModel(url: legacyImageUrl.trim())];
    }

    return const [];
  }
}

class AmenityImageDraft {
  final AmenityImageModel? existingImage;
  final XFile? newFile;

  const AmenityImageDraft.existing(AmenityImageModel image)
    : existingImage = image,
      newFile = null;

  const AmenityImageDraft.file(XFile file)
    : existingImage = null,
      newFile = file;

  bool get isNew => newFile != null;
}

// Amenity Model
class AmenityModel {
  final String id;
  final String name;
  final String type;
  final bool isFree;
  final double pricePerDay;
  final String pricingMode;
  final double? ownerPricePerDay;
  final double? tenantPricePerDay;
  final String? description;
  final String? iconName;
  final String? imageUrl;
  final List<AmenityImageModel> images;
  final bool isAvailable;
  final List<String>? timeSlots; // Time slots like "6:00 AM - 7:00 AM"
  final String buildingId;
  final String buildingName;
  final String adminId;
  // Booking Configuration
  final int maxCapacity; // Maximum number of people/bookings at same time
  final bool
  allowMultipleBookings; // Allow multiple bookings for same time slot
  final List<String>
  bookingDurations; // e.g., ["1 hour", "Half day", "Full day"]
  // Subscription Packages
  final bool
  hasSubscriptionPackages; // Whether this amenity offers subscriptions
  final Map<String, double>
  subscriptionPackages; // e.g., {"Weekly": 500, "Monthly": 1500, "Yearly": 15000}
  final DateTime? createdAt;
  final DateTime? updatedAt;

  AmenityModel({
    required this.id,
    required this.name,
    required this.type,
    required this.isFree,
    required this.pricePerDay,
    String? pricingMode,
    this.ownerPricePerDay,
    this.tenantPricePerDay,
    this.description,
    this.iconName,
    this.imageUrl,
    List<AmenityImageModel>? images,
    required this.isAvailable,
    this.timeSlots,
    required this.buildingId,
    required this.buildingName,
    required this.adminId,
    required this.maxCapacity,
    required this.allowMultipleBookings,
    required this.bookingDurations,
    required this.hasSubscriptionPackages,
    required this.subscriptionPackages,
    this.createdAt,
    this.updatedAt,
  }) : images = images ?? const <AmenityImageModel>[],
       pricingMode = pricingMode ?? (isFree ? 'free' : 'flat');

  factory AmenityModel.fromFirestore(String id, Map<String, dynamic> data) {
    final rawPricingMode = data['pricingMode'];

    final pricingMode =
        rawPricingMode == 'free' ||
            rawPricingMode == 'flat' ||
            rawPricingMode == 'resident_type'
        ? rawPricingMode as String
        : null;

    final rawOwnerPrice = data['ownerPricePerDay'];
    final rawTenantPrice = data['tenantPricePerDay'];

    final ownerPricePerDay =
        rawOwnerPrice is num && rawOwnerPrice.isFinite && rawOwnerPrice >= 0
        ? rawOwnerPrice.toDouble()
        : null;

    final tenantPricePerDay =
        rawTenantPrice is num && rawTenantPrice.isFinite && rawTenantPrice >= 0
        ? rawTenantPrice.toDouble()
        : null;

    final images = AmenityImageModel.fromFirestoreList(
      data['images'],
      legacyImageUrl: data['imageUrl'],
    );

    return AmenityModel(
      id: id,
      name: data['name'] ?? '',
      type: data['type'] ?? '',
      isFree: data['isFree'] ?? true,
      pricePerDay: (data['pricePerDay'] ?? 0).toDouble(),
      pricingMode: pricingMode,
      ownerPricePerDay: ownerPricePerDay,
      tenantPricePerDay: tenantPricePerDay,
      description: data['description'],
      iconName: data['iconName'],
      imageUrl: data['imageUrl'] is String ? data['imageUrl'] as String : null,
      images: images,
      isAvailable: data['isAvailable'] ?? true,
      timeSlots: data['timeSlots'] != null
          ? List<String>.from(data['timeSlots'])
          : null,
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      adminId: data['adminId'] ?? '',
      maxCapacity: data['maxCapacity'] ?? 1,
      allowMultipleBookings: data['allowMultipleBookings'] ?? false,
      bookingDurations: data['bookingDurations'] != null
          ? List<String>.from(data['bookingDurations'])
          : ['1 hour'],
      hasSubscriptionPackages: data['hasSubscriptionPackages'] ?? false,
      subscriptionPackages: data['subscriptionPackages'] != null
          ? Map<String, double>.from(
              (data['subscriptionPackages'] as Map).map(
                (key, value) =>
                    MapEntry(key.toString(), (value as num).toDouble()),
              ),
            )
          : {},
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  String? get primaryImageUrl {
    if (images.isNotEmpty) return images.first.url;
    final legacy = imageUrl?.trim() ?? '';
    return legacy.isEmpty ? null : legacy;
  }

  String get priceDisplay {
    if (pricingMode == 'free' || isFree) return 'Free';

    if (pricingMode == 'resident_type') {
      if (ownerPricePerDay == null || tenantPricePerDay == null) {
        return 'Price unavailable';
      }

      return 'Owner ₹${ownerPricePerDay!.toStringAsFixed(0)} • '
          'Tenant / Lease ₹${tenantPricePerDay!.toStringAsFixed(0)}/day';
    }

    if (hasSubscriptionPackages && subscriptionPackages.isNotEmpty) {
      final firstPackage = subscriptionPackages.entries.first;
      return '₹${firstPackage.value.toStringAsFixed(0)}/${firstPackage.key}';
    }

    return '₹${pricePerDay.toStringAsFixed(0)}/day';
  }

  String get capacityDisplay {
    if (maxCapacity == 1) return '1 person';
    return '$maxCapacity people max';
  }

  IconData get icon {
    switch (iconName) {
      case 'pool':
        return Icons.pool;
      case 'gym':
        return Icons.fitness_center;
      case 'hall':
        return Icons.home;
      case 'lawn':
        return Icons.grass;
      case 'parking':
        return Icons.local_parking;
      case 'playground':
        return Icons.sports_soccer;
      default:
        return Icons.apartment;
    }
  }

  Color get color {
    switch (type.toLowerCase()) {
      case 'sports':
        return Color(0xFF10B981);
      case 'recreation':
        return Color(0xFF2563EB);
      case 'event':
        return Color(0xFF8B5CF6);
      case 'facility':
        return Color(0xFFF4A100);
      default:
        return Color(0xFF6B7280);
    }
  }
}

// Amenity Booking Model
class AmenityBookingModel {
  final String id;
  final String amenityId;
  final String amenityName;
  final String buildingId;
  final String buildingName;
  final String userId;
  final String residentId;
  final String residentName;
  final String flatId;
  final String flatLabel;
  final String phone;
  final String? email;
  final String bookingDate; // YYYY-MM-DD format
  final DateTime? bookingDateTimestamp;
  final String timeSlot; // "6:00 AM - 7:00 AM"
  final String startTime; // "06:00"
  final String endTime; // "07:00"
  final String
  status; // confirmed, cancelled, completed, pending, approved, rejected
  final double amount;
  final String? rejectionReason;
  final String adminId;
  // Package/Subscription fields
  final String? packageType; // "daily", "weekly", "monthly", "yearly"
  final DateTime? packageStartDate;
  final DateTime? packageEndDate;
  final int? packageDurationDays;
  // Family/Group booking fields
  final int totalMembers; // Total people in booking
  final List<String>? familyMemberNames; // Names of family members
  final List<Map<String, dynamic>>?
  familyMembers; // Detailed family member info
  // Capacity tracking
  final int? slotCapacity; // Max capacity for this slot
  final int? currentBookings; // Current bookings for this slot
  final int? spotsRemaining; // Remaining spots
  // Additional booking details
  final String? bookingType; // "single", "recurring", "package"
  final String? notes; // Special notes or requirements
  final String? paymentStatus; // "paid", "pending", "refunded"
  final String? paymentMethod; // "cash", "online", "card"
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? bookedAt;
  final DateTime? approvedAt;
  final DateTime? rejectedAt;
  final DateTime? cancelledAt;

  AmenityBookingModel({
    required this.id,
    required this.amenityId,
    required this.amenityName,
    required this.buildingId,
    required this.buildingName,
    required this.userId,
    required this.residentId,
    required this.residentName,
    required this.flatId,
    required this.flatLabel,
    required this.phone,
    this.email,
    required this.bookingDate,
    this.bookingDateTimestamp,
    required this.timeSlot,
    required this.startTime,
    required this.endTime,
    required this.status,
    required this.amount,
    this.rejectionReason,
    required this.adminId,
    this.packageType,
    this.packageStartDate,
    this.packageEndDate,
    this.packageDurationDays,
    this.totalMembers = 1,
    this.familyMemberNames,
    this.familyMembers,
    this.slotCapacity,
    this.currentBookings,
    this.spotsRemaining,
    this.bookingType,
    this.notes,
    this.paymentStatus,
    this.paymentMethod,
    this.createdAt,
    this.updatedAt,
    this.bookedAt,
    this.approvedAt,
    this.rejectedAt,
    this.cancelledAt,
  });

  factory AmenityBookingModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    // Handle date field - Firestore uses 'date' as Timestamp
    DateTime? dateTimestamp;
    String dateString = '';

    if (data['date'] != null && data['date'] is Timestamp) {
      dateTimestamp = (data['date'] as Timestamp).toDate();
      dateString =
          '${dateTimestamp.year}-${dateTimestamp.month.toString().padLeft(2, '0')}-${dateTimestamp.day.toString().padLeft(2, '0')}';
    }

    // Parse family members list
    List<String>? familyMemberNames;
    List<Map<String, dynamic>>? familyMembers;

    if (data['familyMemberNames'] != null) {
      familyMemberNames = List<String>.from(data['familyMemberNames']);
    }

    if (data['familyMembers'] != null) {
      familyMembers = List<Map<String, dynamic>>.from(
        (data['familyMembers'] as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );
    }

    return AmenityBookingModel(
      id: id,
      amenityId: data['amenityId'] ?? '',
      amenityName: data['amenityName'] ?? '',
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      userId: data['userId'] ?? '',
      residentId: data['residentId'] ?? data['userId'] ?? '',
      residentName: data['residentName'] ?? data['userName'] ?? '',
      flatId: data['flatId'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      phone: data['phone'] ?? data['userPhone'] ?? '',
      email: data['email'] ?? data['userEmail'],
      bookingDate: dateString,
      bookingDateTimestamp: dateTimestamp,
      timeSlot: data['timeSlot'] ?? '',
      startTime: data['startTime'] ?? '',
      endTime: data['endTime'] ?? '',
      status: data['status'] ?? 'pending',
      amount: (data['amount'] ?? 0).toDouble(),
      rejectionReason: data['rejectionReason'],
      adminId: data['adminId'] ?? '',
      // Package fields
      packageType: data['packageType'],
      packageStartDate: (data['packageStartDate'] as Timestamp?)?.toDate(),
      packageEndDate: (data['packageEndDate'] as Timestamp?)?.toDate(),
      packageDurationDays: data['packageDurationDays'],
      // Family/Group fields
      totalMembers: data['totalMembers'] ?? 1,
      familyMemberNames: familyMemberNames,
      familyMembers: familyMembers,
      // Capacity fields
      slotCapacity: data['slotCapacity'],
      currentBookings: data['currentBookings'],
      spotsRemaining: data['spotsRemaining'],
      // Additional fields
      bookingType: data['bookingType'],
      notes: data['notes'],
      paymentStatus: data['paymentStatus'],
      paymentMethod: data['paymentMethod'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      bookedAt: (data['bookedAt'] as Timestamp?)?.toDate(),
      approvedAt: (data['approvedAt'] as Timestamp?)?.toDate(),
      rejectedAt: (data['rejectedAt'] as Timestamp?)?.toDate(),
      cancelledAt: (data['cancelledAt'] as Timestamp?)?.toDate(),
    );
  }

  String get formattedDate {
    // Try to use bookingDateTimestamp first if available
    if (bookingDateTimestamp != null) {
      return '${bookingDateTimestamp!.day.toString().padLeft(2, '0')}/${bookingDateTimestamp!.month.toString().padLeft(2, '0')}/${bookingDateTimestamp!.year}';
    }

    // Fall back to parsing bookingDate string
    if (bookingDate.isEmpty) return '';

    // Parse YYYY-MM-DD format
    try {
      final parts = bookingDate.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}'; // DD/MM/YYYY
      }
    } catch (e) {
      print('Error parsing date: $e');
    }
    return bookingDate;
  }

  String get formattedTime {
    return timeSlot; // Already in "6:00 AM - 7:00 AM" format
  }

  String get packageDisplay {
    if (packageType == null) return 'Single booking';

    switch (packageType!.toLowerCase()) {
      case 'daily':
        return 'Daily Package';
      case 'weekly':
        return 'Weekly Package';
      case 'monthly':
        return 'Monthly Package';
      case 'yearly':
        return 'Yearly Package';
      default:
        return packageType!;
    }
  }

  String get packageDurationDisplay {
    if (packageStartDate == null || packageEndDate == null) return '';

    final start =
        '${packageStartDate!.day}/${packageStartDate!.month}/${packageStartDate!.year}';
    final end =
        '${packageEndDate!.day}/${packageEndDate!.month}/${packageEndDate!.year}';

    return '$start - $end';
  }

  String get capacityDisplay {
    if (slotCapacity == null) return '';

    final current = currentBookings ?? 0;
    final remaining = spotsRemaining ?? (slotCapacity! - current);

    return '$current/$slotCapacity booked ($remaining spots left)';
  }

  String get membersDisplay {
    if (totalMembers <= 1) return '1 person';
    return '$totalMembers people';
  }

  Color get statusColor {
    switch (status.toLowerCase()) {
      case 'confirmed':
      case 'approved':
        return Color(0xFF10B981);
      case 'pending':
        return Color(0xFFF4A100);
      case 'rejected':
        return Color(0xFFEF4444);
      case 'cancelled':
        return Color(0xFF6B7280);
      case 'completed':
        return Color(0xFF2563EB);
      default:
        return Color(0xFF6B7280);
    }
  }

  String get statusDisplay {
    return status[0].toUpperCase() + status.substring(1);
  }

  Color get paymentStatusColor {
    switch (paymentStatus?.toLowerCase() ?? '') {
      case 'paid':
        return Color(0xFF10B981);
      case 'pending':
        return Color(0xFFF4A100);
      case 'refunded':
        return Color(0xFF6B7280);
      default:
        return Color(0xFF6B7280);
    }
  }
}
