import 'package:cloud_firestore/cloud_firestore.dart';

/// Resident Deletion Service - Handles cascading deletion of resident data
/// Implements 5-step flow function pattern for resident deletion
class ResidentDeletionService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Delete resident and cascade delete all related data
  /// Follows 5-step flow function pattern
  Future<ResidentDeletionResult> deleteResident(String userId) async {
    try {
      print('🔵 RESIDENT DELETION FLOW: Starting...');
      
      // STEP 1: Validate resident exists
      print('📋 STEP 1: Validating resident...');
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) {
        print('❌ STEP 1 FAILED: Resident not found');
        throw Exception('Resident not found');
      }
      
      final userData = userDoc.data();
      if (userData == null) {
        print('❌ STEP 1 FAILED: Resident data is empty');
        throw Exception('Resident data is empty');
      }
      
      final residentName = userData['name'] as String?;
      final flatId = userData['flatId'] as String?;
      print('   - Resident: $residentName');
      print('   - Flat: $flatId');
      print('✅ STEP 1 PASSED: Resident validated');
      
      // STEP 2: Remove resident from flat members array
      print('📝 STEP 2: Removing resident from flat...');
      if (flatId != null && flatId.isNotEmpty) {
        try {
          final flatDoc = await _firestore.collection('flats').doc(flatId).get();
          if (flatDoc.exists) {
            // Remove resident from flat
            await _firestore.collection('flats').doc(flatId).update({
              'residentName': null,
              'residentId': null,
              'residentUserId': null,
              'status': 'vacant',
              'updatedAt': FieldValue.serverTimestamp(),
            });
            print('   - Resident removed from flat');
          }
        } catch (e) {
          print('   - Warning: Could not update flat - $e');
        }
      }
      print('✅ STEP 2 PASSED: Resident removed from flat');
      
      // STEP 3: Delete user-related data
      print('📝 STEP 3: Deleting user-related data...');
      
      // Delete notifications
      final notificationsSnapshot = await _firestore
          .collection('notifications')
          .where('residentId', isEqualTo: userId)
          .get();
      print('   - Deleting ${notificationsSnapshot.docs.length} notifications');
      
      final notificationBatch = _firestore.batch();
      for (var doc in notificationsSnapshot.docs) {
        notificationBatch.delete(doc.reference);
      }
      await notificationBatch.commit();
      
      // Delete chat messages
      final messagesSnapshot = await _firestore
          .collection('messages')
          .where('senderId', isEqualTo: userId)
          .get();
      print('   - Deleting ${messagesSnapshot.docs.length} messages');
      
      final messageBatch = _firestore.batch();
      for (var doc in messagesSnapshot.docs) {
        messageBatch.delete(doc.reference);
      }
      await messageBatch.commit();
      
      // Delete complaints
      final complaintsSnapshot = await _firestore
          .collection('complaints')
          .where('residentId', isEqualTo: userId)
          .get();
      print('   - Deleting ${complaintsSnapshot.docs.length} complaints');
      
      final complaintBatch = _firestore.batch();
      for (var doc in complaintsSnapshot.docs) {
        complaintBatch.delete(doc.reference);
      }
      await complaintBatch.commit();
      
      // Delete visitor requests
      final visitorsSnapshot = await _firestore
          .collection('visitors')
          .where('residentId', isEqualTo: userId)
          .get();
      print('   - Deleting ${visitorsSnapshot.docs.length} visitor requests');
      
      final visitorBatch = _firestore.batch();
      for (var doc in visitorsSnapshot.docs) {
        visitorBatch.delete(doc.reference);
      }
      await visitorBatch.commit();
      
      // Delete amenity bookings
      final bookingsSnapshot = await _firestore
          .collection('amenity_bookings')
          .where('residentId', isEqualTo: userId)
          .get();
      print('   - Deleting ${bookingsSnapshot.docs.length} amenity bookings');
      
      final bookingBatch = _firestore.batch();
      for (var doc in bookingsSnapshot.docs) {
        bookingBatch.delete(doc.reference);
      }
      await bookingBatch.commit();
      
      print('✅ STEP 3 PASSED: All user-related data deleted');
      
      // STEP 4: Delete user document
      print('📝 STEP 4: Deleting user document...');
      await _firestore.collection('users').doc(userId).delete();
      print('✅ STEP 4 PASSED: User document deleted');
      
      // STEP 5: Return result
      print('✅ RESIDENT DELETION FLOW: COMPLETE');
      print('   - Resident: $residentName');
      print('   - Notifications deleted: ${notificationsSnapshot.docs.length}');
      print('   - Messages deleted: ${messagesSnapshot.docs.length}');
      print('   - Complaints deleted: ${complaintsSnapshot.docs.length}');
      print('   - Visitor requests deleted: ${visitorsSnapshot.docs.length}');
      print('   - Amenity bookings deleted: ${bookingsSnapshot.docs.length}');
      
      return ResidentDeletionResult.success(
        userId: userId,
        residentName: residentName ?? 'Unknown',
        notificationsDeleted: notificationsSnapshot.docs.length,
        messagesDeleted: messagesSnapshot.docs.length,
        complaintsDeleted: complaintsSnapshot.docs.length,
        visitorsDeleted: visitorsSnapshot.docs.length,
        bookingsDeleted: bookingsSnapshot.docs.length,
      );
    } catch (e) {
      print('❌ ERROR: $e');
      return ResidentDeletionResult.failure('Failed to delete resident: $e');
    }
  }

  /// Delete multiple residents
  Future<void> deleteMultipleResidents(List<String> userIds) async {
    print('🔵 BATCH RESIDENT DELETION: Starting...');
    print('   - Residents to delete: ${userIds.length}');
    
    int successCount = 0;
    int failureCount = 0;
    
    for (var userId in userIds) {
      try {
        final result = await deleteResident(userId);
        if (result.success) {
          successCount++;
        } else {
          failureCount++;
        }
      } catch (e) {
        print('❌ Error deleting resident $userId: $e');
        failureCount++;
      }
    }
    
    print('✅ BATCH RESIDENT DELETION: COMPLETE');
    print('   - Successful: $successCount');
    print('   - Failed: $failureCount');
  }
}

/// Result of resident deletion
class ResidentDeletionResult {
  final bool success;
  final String message;
  final String? userId;
  final String? residentName;
  final int? notificationsDeleted;
  final int? messagesDeleted;
  final int? complaintsDeleted;
  final int? visitorsDeleted;
  final int? bookingsDeleted;

  ResidentDeletionResult({
    required this.success,
    required this.message,
    this.userId,
    this.residentName,
    this.notificationsDeleted,
    this.messagesDeleted,
    this.complaintsDeleted,
    this.visitorsDeleted,
    this.bookingsDeleted,
  });

  factory ResidentDeletionResult.success({
    required String userId,
    required String residentName,
    required int notificationsDeleted,
    required int messagesDeleted,
    required int complaintsDeleted,
    required int visitorsDeleted,
    required int bookingsDeleted,
  }) {
    return ResidentDeletionResult(
      success: true,
      message: 'Resident deleted successfully',
      userId: userId,
      residentName: residentName,
      notificationsDeleted: notificationsDeleted,
      messagesDeleted: messagesDeleted,
      complaintsDeleted: complaintsDeleted,
      visitorsDeleted: visitorsDeleted,
      bookingsDeleted: bookingsDeleted,
    );
  }

  factory ResidentDeletionResult.failure(String message) {
    return ResidentDeletionResult(
      success: false,
      message: message,
    );
  }
}
