// lib/src/services/notice_firestore_service.dart
// Notice/Notification Firestore Service - Fetch notices from Firestore

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/notice_model.dart';

/// Notice Firestore Service
class NoticeFirestoreService {
  // Singleton pattern
  static final NoticeFirestoreService instance = NoticeFirestoreService._internal();
  factory NoticeFirestoreService() => instance;
  NoticeFirestoreService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection name
  static const String noticesCollection = 'notices';

  // ============================================================================
  // GET NOTICES
  // ============================================================================

  /// Get all active notices for current user
  /// Filters by:
  /// - isActive: true OR status: "published"
  /// - Not expired
  /// - targetFlats is empty (all flats) OR contains user's flat
  Future<List<NoticeModel>> getNotices() async {
    try {
      print('🔵 Fetching notices from Firestore...');
      
      final user = _auth.currentUser;
      if (user == null) {
        print('❌ No user logged in');
        return [];
      }

      // Get user's flat ID
      String? userFlatId;
      try {
        final userDoc = await _firestore
            .collection('users')
            .where('authUid', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          userFlatId = userDoc.docs.first.data()['flatId'] as String?;
          print('🔵 User flat ID: $userFlatId');
        }
      } catch (e) {
        print('⚠️ Could not fetch user flat: $e');
      }

      // Fetch ALL notices without any where clause to avoid index issues
      print('🔵 Querying notices collection...');
      final snapshot = await _firestore
          .collection(noticesCollection)
          .get();

      print('🔵 Found ${snapshot.docs.length} total notices in Firestore');

      final now = DateTime.now();
      final notices = <NoticeModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          print('📄 Processing notice: ${doc.id}');
          print('   Raw data keys: ${data.keys.toList()}');
          print('   status: ${data['status']}');
          print('   isActive: ${data['isActive']}');
          
          // Check if notice is active/published
          final isActive = data['isActive'] == true || data['status'] == 'published';
          if (!isActive) {
            print('⏭️ Skipping inactive notice: ${doc.id} (status=${data['status']}, isActive=${data['isActive']})');
            continue;
          }

          // Parse dates - handle both field name variations
          DateTime? publishDate;
          DateTime? expiryDate;
          
          // publishDate / publishedAt
          try {
            if (data['publishDate'] != null) {
              publishDate = (data['publishDate'] as Timestamp).toDate();
              print('   publishDate: $publishDate');
            } else if (data['publishedAt'] != null) {
              publishDate = (data['publishedAt'] as Timestamp).toDate();
              print('   publishedAt: $publishDate');
            } else if (data['createdAt'] != null) {
              publishDate = (data['createdAt'] as Timestamp).toDate();
              print('   using createdAt: $publishDate');
            } else {
              publishDate = DateTime.now();
              print('   using now: $publishDate');
            }
          } catch (e) {
            print('   ⚠️ Error parsing publishDate: $e');
            publishDate = DateTime.now();
          }
          
          // expiryDate / expiresAt
          try {
            if (data['expiryDate'] != null) {
              expiryDate = (data['expiryDate'] as Timestamp).toDate();
              print('   expiryDate: $expiryDate');
            } else if (data['expiresAt'] != null) {
              expiryDate = (data['expiresAt'] as Timestamp).toDate();
              print('   expiresAt: $expiryDate');
            }
          } catch (e) {
            print('   ⚠️ Error parsing expiryDate: $e');
          }
          
          // Check if expired
          if (expiryDate != null && now.isAfter(expiryDate)) {
            print('⏭️ Skipping expired notice: ${data['title'] ?? doc.id} (expired: $expiryDate)');
            continue;
          }

          // Create notice model with flexible field mapping
          // Handle both 'type' and 'category' field names
          final categoryValue = (data['type'] as String?) ?? (data['category'] as String?) ?? 'general';
          print('   category/type: $categoryValue');
          
          final targetFlats = (data['targetFlats'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          
          // Check if notice is for this user's flat
          // If targetFlats is empty, show to all users
          // If targetFlats has values, only show if user's flat is in the list
          if (targetFlats.isNotEmpty && userFlatId != null && !targetFlats.contains(userFlatId)) {
            print('⏭️ Skipping notice not targeted to user flat: $userFlatId');
            continue;
          }
          
          final notice = NoticeModel(
            id: doc.id,
            title: data['title'] as String? ?? 'Notice',
            content: data['content'] as String? ?? '',
            category: categoryValue,
            priority: data['priority'] as String? ?? 'medium',
            authorId: data['authorId'] as String? ?? '',
            authorName: data['authorName'] as String? ?? 'Admin',
            attachments: (data['attachments'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            publishDate: publishDate,
            expiryDate: expiryDate,
            isActive: isActive,
            targetFlats: targetFlats,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );

          // Add notice if it passes all filters
          notices.add(notice);
          print('✅ Added notice: ${notice.title}');
        } catch (e, stackTrace) {
          print('❌ Error parsing notice ${doc.id}: $e');
          print('   Stack trace: $stackTrace');
        }
      }

      print('✅ Returning ${notices.length} notices');
      
      // Sort by publish date (newest first)
      notices.sort((a, b) => b.publishDate.compareTo(a.publishDate));
      
      return notices;
    } catch (e, stackTrace) {
      print('❌ Error fetching notices: $e');
      print('   Stack trace: $stackTrace');
      return [];
    }
  }

  /// Stream notices (real-time updates)
  Stream<List<NoticeModel>> streamNotices() {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return _firestore
        .collection(noticesCollection)
        .snapshots()
        .asyncMap((snapshot) async {
      print('🔄 Real-time notice update: ${snapshot.docs.length} notices');

      // Get user's flat ID
      String? userFlatId;
      try {
        final userDoc = await _firestore
            .collection('users')
            .where('authUid', isEqualTo: user.uid)
            .limit(1)
            .get();
        
        if (userDoc.docs.isNotEmpty) {
          userFlatId = userDoc.docs.first.data()['flatId'] as String?;
        }
      } catch (e) {
        print('⚠️ Could not fetch user flat: $e');
      }

      final now = DateTime.now();
      final notices = <NoticeModel>[];

      for (var doc in snapshot.docs) {
        try {
          final data = doc.data();
          
          // Check if notice is active/published
          final isActive = data['isActive'] == true || data['status'] == 'published';
          if (!isActive) continue;

          // Parse dates - handle both field name variations
          DateTime? publishDate;
          DateTime? expiryDate;
          
          try {
            if (data['publishDate'] != null) {
              publishDate = (data['publishDate'] as Timestamp).toDate();
            } else if (data['publishedAt'] != null) {
              publishDate = (data['publishedAt'] as Timestamp).toDate();
            } else if (data['createdAt'] != null) {
              publishDate = (data['createdAt'] as Timestamp).toDate();
            } else {
              publishDate = DateTime.now();
            }
          } catch (e) {
            publishDate = DateTime.now();
          }
          
          try {
            if (data['expiryDate'] != null) {
              expiryDate = (data['expiryDate'] as Timestamp).toDate();
            } else if (data['expiresAt'] != null) {
              expiryDate = (data['expiresAt'] as Timestamp).toDate();
            }
          } catch (e) {
            // No expiry date
          }
          
          // Check if expired
          if (expiryDate != null && now.isAfter(expiryDate)) continue;

          // Create notice model with flexible field mapping
          // Handle both 'type' and 'category' field names
          final categoryValue = (data['type'] as String?) ?? (data['category'] as String?) ?? 'general';
          
          final targetFlats = (data['targetFlats'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [];
          
          // Check if notice is for this user's flat
          // If targetFlats is empty, show to all users
          // If targetFlats has values, only show if user's flat is in the list
          if (targetFlats.isNotEmpty && userFlatId != null && !targetFlats.contains(userFlatId)) {
            continue;
          }
          
          final notice = NoticeModel(
            id: doc.id,
            title: data['title'] as String? ?? 'Notice',
            content: data['content'] as String? ?? '',
            category: categoryValue,
            priority: data['priority'] as String? ?? 'medium',
            authorId: data['authorId'] as String? ?? '',
            authorName: data['authorName'] as String? ?? 'Admin',
            attachments: (data['attachments'] as List<dynamic>?)
                    ?.map((e) => e as String)
                    .toList() ??
                [],
            publishDate: publishDate,
            expiryDate: expiryDate,
            isActive: isActive,
            targetFlats: targetFlats,
            createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
            updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          );

          // Add notice if it passes all filters
          notices.add(notice);
        } catch (e) {
          print('❌ Error parsing notice ${doc.id}: $e');
        }
      }

      // Sort by publish date (newest first)
      notices.sort((a, b) => b.publishDate.compareTo(a.publishDate));

      return notices;
    });
  }

  // ============================================================================
  // MARK AS READ (Optional - for future use)
  // ============================================================================

  /// Mark notice as read for current user
  /// This creates a read receipt in a subcollection
  Future<void> markAsRead(String noticeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      await _firestore
          .collection(noticesCollection)
          .doc(noticeId)
          .collection('readBy')
          .doc(user.uid)
          .set({
        'readAt': FieldValue.serverTimestamp(),
        'userId': user.uid,
      });

      print('✅ Marked notice $noticeId as read');
    } catch (e) {
      print('❌ Error marking notice as read: $e');
    }
  }

  /// Check if notice has been read by current user
  Future<bool> isRead(String noticeId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return false;

      final doc = await _firestore
          .collection(noticesCollection)
          .doc(noticeId)
          .collection('readBy')
          .doc(user.uid)
          .get();

      return doc.exists;
    } catch (e) {
      print('❌ Error checking read status: $e');
      return false;
    }
  }

  /// Get unread count
  Future<int> getUnreadCount() async {
    try {
      final notices = await getNotices();
      int unreadCount = 0;

      for (var notice in notices) {
        final isRead = await this.isRead(notice.id);
        if (!isRead) unreadCount++;
      }

      return unreadCount;
    } catch (e) {
      print('❌ Error getting unread count: $e');
      return 0;
    }
  }
}
