import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/visitor_model.dart';

class VisitorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collection = 'visitors';
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> _requireSecurityCommunityId() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw Exception('Security user is not authenticated.');
    }

    final staffDoc = await _firestore
        .collection('securityStaff')
        .doc(user.uid)
        .get();

    if (!staffDoc.exists) {
      throw Exception('Security profile not found.');
    }

    final data = staffDoc.data();

    if (data == null) {
      throw Exception('Security profile is invalid.');
    }

    if (data['uid'] != user.uid) {
      throw Exception('Security profile UID mismatch.');
    }

    if (data['role'] != 'security') {
      throw Exception('Invalid Security role.');
    }

    if (data['isActive'] != true) {
      throw Exception('Security account is inactive.');
    }

    final communityId = data['communityId'];

    if (communityId is! String || communityId.trim().isEmpty) {
      throw Exception('Security community is not assigned.');
    }

    return communityId.trim();
  }

  /// Get visitor by ID
  Future<VisitorModel?> getVisitorById(String visitorId) async {
    try {
      print('VisitorService: Fetching visitor by ID - $visitorId');
      final doc = await _firestore.collection(_collection).doc(visitorId).get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          print(
            'VisitorService: Visitor found - ${data['visitorName'] ?? data['hostName']}',
          );
          return VisitorModel.fromFirestore(doc.id, data);
        }
      }

      print('VisitorService: Visitor not found - $visitorId');
      return null;
    } catch (e) {
      print('VisitorService ERROR: Failed to fetch visitor: $e');
      return null;
    }
  }

  /// Get pending visitors (real-time stream)
  Stream<List<VisitorModel>> getPendingVisitors() async* {
    print('VisitorService: Fetching pending visitors');

    final communityId = await _requireSecurityCommunityId();

    print('VisitorService SECURITY UID: ${_auth.currentUser?.uid}');
    print('VisitorService COMMUNITY: $communityId');

    yield* _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          print(
            'VisitorService TEST: Received '
            '${snapshot.docs.length} community visitors',
          );

          return snapshot.docs
              .where((doc) {
                final data = doc.data();
                final status =
                    data['status']?.toString().trim().toLowerCase() ?? '';

                return data['isApproved'] == false &&
                    status != 'rejected' &&
                    status != 'cancelled' &&
                    data['actualArrival'] == null;
              })
              .map((doc) => VisitorModel.fromFirestore(doc.id, doc.data()))
              .toList();
        });
  }

  /// Get active visitors (checked-in, real-time stream)
  /// Active visitors for the authenticated Security user's community.
  Stream<List<VisitorModel>> getActiveVisitors() async* {
    print('VisitorService: Fetching active visitors');

    final communityId = await _requireSecurityCommunityId();

    print('VisitorService ACTIVE COMMUNITY: $communityId');

    yield* _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .where('isApproved', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          print(
            'VisitorService: Received '
            '${snapshot.docs.length} approved community visitors',
          );

          final visitors = snapshot.docs
              .where((doc) {
                final data = doc.data();

                final actualArrival = data['actualArrival'];
                final departure = data['departure'];

                return data['status'] == 'inside' &&
                    data['isApproved'] == true &&
                    actualArrival != null &&
                    departure == null;
              })
              .map((doc) => VisitorModel.fromFirestore(doc.id, doc.data()))
              .toList();

          visitors.sort((a, b) {
            if (a.checkInTime == null && b.checkInTime == null) {
              return 0;
            }

            if (a.checkInTime == null) return 1;
            if (b.checkInTime == null) return -1;

            return b.checkInTime!.compareTo(a.checkInTime!);
          });

          return visitors;
        });
  }

  /// Get history visitors (checked-out, real-time stream)
  /// Visitor history for the authenticated Security user's community.
  Stream<List<VisitorModel>> getHistoryVisitors() async* {
    print('VisitorService: Fetching history visitors');

    final communityId = await _requireSecurityCommunityId();

    print('VisitorService HISTORY COMMUNITY: $communityId');

    yield* _firestore
        .collection(_collection)
        .where('communityId', isEqualTo: communityId)
        .snapshots()
        .map((snapshot) {
          print(
            'VisitorService: Received '
            '${snapshot.docs.length} community visitors for history',
          );

          final visitors = snapshot.docs
              .where((doc) {
                final data = doc.data();
                return data['status'] == 'completed' &&
                    data['departure'] != null;
              })
              .map((doc) => VisitorModel.fromFirestore(doc.id, doc.data()))
              .toList();

          visitors.sort((a, b) {
            if (a.checkOutTime == null && b.checkOutTime == null) {
              return 0;
            }

            if (a.checkOutTime == null) return 1;
            if (b.checkOutTime == null) return -1;

            return b.checkOutTime!.compareTo(a.checkOutTime!);
          });

          return visitors.take(50).toList();
        });
  }

  /// Approve visitor (admin action)
  Future<void> approveVisitor(String visitorId) async {
    try {
      print('VisitorService: Approving visitor - $visitorId');
      final actorId = _auth.currentUser?.uid;
      if (actorId == null) {
        throw Exception('Security user is not authenticated.');
      }
      await _firestore.collection(_collection).doc(visitorId).update({
        'status': 'approved',
        'approvedBy': actorId,
        'isApproved': true,
        'approvedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('VisitorService: Visitor approved successfully');
    } catch (e) {
      print('VisitorService ERROR: Failed to approve visitor: $e');
      throw Exception('Failed to approve visitor: $e');
    }
  }

  /// Reject visitor (admin action)
  Future<void> rejectVisitor(String visitorId) async {
    try {
      print('VisitorService: Rejecting visitor - $visitorId');
      final rejectedBy = _auth.currentUser?.uid;
      if (rejectedBy == null || rejectedBy.isEmpty) {
        throw Exception('Security user is not authenticated.');
      }

      await _firestore.collection(_collection).doc(visitorId).update({
        'status': 'rejected',
        'isApproved': false,
        'rejectedBy': rejectedBy,
        'rejectedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      print('VisitorService: Visitor rejected successfully');
    } catch (e) {
      print('VisitorService ERROR: Failed to reject visitor: $e');
      throw Exception('Failed to reject visitor: $e');
    }
  }

  /// Gate admission may approve a pending invitation atomically.
  Future<void> checkInVisitor(String visitorId) async {
    final actorId = _auth.currentUser?.uid;
    if (actorId == null) {
      throw Exception('Security user is not authenticated.');
    }
    final ref = _firestore.collection(_collection).doc(visitorId);
    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(ref);
      if (!snapshot.exists) {
        throw Exception('Visitor not found.');
      }
      transaction.update(ref, {
        'status': 'inside',
        'isApproved': true,
        'actualArrival': FieldValue.serverTimestamp(),
        'checkedInBy': actorId,
        if (snapshot.data()?['isApproved'] != true) ...{
          'approvedBy': actorId,
          'approvedAt': FieldValue.serverTimestamp(),
        },
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> checkOutVisitor(String visitorId) async {
    final actorId = _auth.currentUser?.uid;
    if (actorId == null) {
      throw Exception('Security user is not authenticated.');
    }
    await _firestore.collection(_collection).doc(visitorId).update({
      'status': 'completed',
      'departure': FieldValue.serverTimestamp(),
      'checkedOutBy': actorId,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Delete visitor record
  Future<void> deleteVisitor(String visitorId) async {
    try {
      await _firestore.collection(_collection).doc(visitorId).delete();
      print('VisitorService: Visitor deleted - $visitorId');
    } catch (e) {
      print('VisitorService ERROR: Failed to delete visitor: $e');
      throw Exception('Failed to delete visitor: $e');
    }
  }
}
