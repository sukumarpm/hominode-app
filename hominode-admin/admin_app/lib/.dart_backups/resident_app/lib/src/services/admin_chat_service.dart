// lib/src/services/admin_chat_service.dart
// Service for admin chat functionality

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/admin_chat_model.dart';
import 'user_data_service.dart';

class AdminChatService {
  // Singleton pattern
  static final AdminChatService instance = AdminChatService._internal();
  factory AdminChatService() => instance;
  AdminChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService.instance;

  static const String adminChatsCollection = 'adminChats';
  static const String messagesSubcollection = 'messages';
  static const String usersCollection = 'users';

  // ============================================================================
  // ADMIN CHAT OPERATIONS
  // ============================================================================

  /// Get or create admin chat for current resident
  /// Flow Function:
  /// 1. Get current user data (buildingId, residentId, flatId)
  /// 2. Find building admin by buildingId + role
  /// 3. Check if admin chat exists
  /// 4. Return existing or create new
  Future<AdminChatModel?> getOrCreateAdminChat({
    required QueryCategory category,
    String? initialMessage,
  }) async {
    try {
      print('\n═══════════════════════════════════════════════════');
      print('📋 GET OR CREATE ADMIN CHAT');
      print('═══════════════════════════════════════════════════\n');

      // STEP 1: Get current user data
      print('📋 STEP 1: Get Current User Data');
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ No user data found');
        print('   User must be logged in with valid Firestore user document');
        return null;
      }

      final residentId = userData['id'];
      final residentName = userData['name'] ?? 'Resident';
      final residentPhoto = userData['photoUrl'] ?? userData['profileImage'];
      var buildingId = userData['buildingId'];
      final flatId = userData['flatId'];
      final flatNumber = userData['flatNumber'] ?? userData['flatLabel'] ?? 'Unknown';

      print('✅ Current User:');
      print('   Resident ID: $residentId');
      print('   Name: $residentName');
      print('   Building ID: $buildingId');
      print('   Flat ID: $flatId');
      print('   Flat: $flatNumber\n');

      // If no buildingId, try to get it from flat document
      if (buildingId == null || buildingId.isEmpty) {
        print('⚠️  No buildingId in user document');
        
        if (flatId != null && flatId.isNotEmpty) {
          print('   Trying to get buildingId from flat document...');
          try {
            final flatDoc = await _firestore.collection('flats').doc(flatId).get();
            if (flatDoc.exists) {
              buildingId = flatDoc.data()?['buildingId'];
              if (buildingId != null) {
                print('✅ Got buildingId from flat: $buildingId');
              }
            }
          } catch (e) {
            print('⚠️  Could not fetch flat document: $e');
          }
        }
        
        // If still no buildingId, use a default
        if (buildingId == null || buildingId.isEmpty) {
          print('⚠️  Using default buildingId');
          buildingId = 'default_building';
        }
      }

      // STEP 2: Find building admin
      print('📋 STEP 2: Find Building Admin');
      print('🔍 Query: users.where("buildingId", isEqualTo: "$buildingId")');
      print('         .where("role", isEqualTo: "admin")');
      
      final adminQuery = await _firestore
          .collection(usersCollection)
          .where('buildingId', isEqualTo: buildingId)
          .where('role', isEqualTo: 'admin')
          .limit(1)
          .get();

      String adminId;
      String adminName;
      String? adminPhoto;

      if (adminQuery.docs.isEmpty) {
        print('⚠️  No admin found for building: $buildingId');
        print('   Using placeholder admin ID');
        print('   Admin can respond when admin user is created');
        // Use placeholder admin ID when no admin exists
        adminId = 'admin_placeholder_$buildingId';
        adminName = 'Building Admin';
        adminPhoto = null;
      } else {
        final adminDoc = adminQuery.docs.first;
        final adminData = adminDoc.data();
        adminId = adminDoc.id;
        adminName = adminData['name'] ?? 'Building Admin';
        adminPhoto = adminData['photoUrl'] ?? adminData['profileImage'];
        
        print('✅ Admin Found:');
        print('   Admin ID: $adminId');
        print('   Name: $adminName\n');
      }

      // STEP 3: Check if admin chat exists
      print('📋 STEP 3: Check Existing Admin Chat');
      final chatId = 'admin_${buildingId}_$residentId';
      print('   Chat ID: $chatId');
      
      final chatDoc = await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .get();

      if (chatDoc.exists) {
        print('✅ Existing admin chat found\n');
        return AdminChatModel.fromFirestore(chatDoc);
      }

      // STEP 4: Create new admin chat
      print('📋 STEP 4: Create New Admin Chat');
      print('   Category: ${category.displayName}');
      
      final now = DateTime.now();
      
      final chatData = AdminChatModel(
        id: chatId,
        buildingId: buildingId,
        adminId: adminId,
        adminName: adminName,
        adminPhoto: adminPhoto,
        residentId: residentId,
        residentName: residentName,
        residentPhoto: residentPhoto,
        flatId: flatId ?? '',
        flatNumber: flatNumber,
        status: AdminChatStatus.open,
        category: category,
        lastMessage: initialMessage,
        lastMessageTime: initialMessage != null ? now : null,
        lastMessageBy: initialMessage != null ? 'resident' : null,
        createdAt: now,
        updatedAt: now,
      );

      print('   Writing to Firestore: $adminChatsCollection/$chatId');
      await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .set(chatData.toFirestore());

      print('✅ Admin chat document created');

      // Add initial message if provided
      if (initialMessage != null && initialMessage.isNotEmpty) {
        print('   Adding initial message...');
        final messageId = await sendMessage(
          chatId: chatId,
          text: initialMessage,
          isQuery: true,
          queryType: category,
        );
        
        if (messageId != null) {
          print('✅ Initial message added: $messageId');
        } else {
          print('⚠️  Failed to add initial message (chat still created)');
        }
      }

      print('✅ Admin chat created successfully: $chatId\n');
      print('═══════════════════════════════════════════════════\n');
      
      return chatData;
    } catch (e, stackTrace) {
      print('❌ AdminChatService: Error getting/creating admin chat');
      print('   Error: $e');
      print('   Stack trace: $stackTrace');
      return null;
    }
  }

  /// Get existing admin chat for current resident
  Future<AdminChatModel?> getExistingAdminChat() async {
    try {
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        return null;
      }

      final residentId = userData['id'];
      final buildingId = userData['buildingId'];

      if (buildingId == null || buildingId.isEmpty) {
        return null;
      }

      final chatId = 'admin_${buildingId}_$residentId';
      
      final chatDoc = await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        return null;
      }

      return AdminChatModel.fromFirestore(chatDoc);
    } catch (e) {
      print('❌ AdminChatService: Error getting existing chat: $e');
      return null;
    }
  }

  /// Stream admin chat messages
  Stream<List<AdminChatMessageModel>> streamMessages(String chatId) {
    try {
      print('📡 AdminChatService: Streaming messages for chat: $chatId');

      return _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .collection(messagesSubcollection)
          .orderBy('timestamp', descending: false)
          .snapshots()
          .map((snapshot) {
        print('📊 AdminChatService: Received ${snapshot.docs.length} messages');
        
        return snapshot.docs.map((doc) {
          try {
            return AdminChatMessageModel.fromFirestore(doc);
          } catch (e) {
            print('⚠️  AdminChatService: Error parsing message ${doc.id}: $e');
            return null;
          }
        }).whereType<AdminChatMessageModel>().toList();
      });
    } catch (e) {
      print('❌ AdminChatService: Error streaming messages: $e');
      return Stream.value([]);
    }
  }

  /// Send message in admin chat
  Future<String?> sendMessage({
    required String chatId,
    required String text,
    bool isQuery = false,
    QueryCategory? queryType,
  }) async {
    try {
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ AdminChatService: No user data');
        return null;
      }

      final senderId = userData['id'];
      final senderName = userData['name'] ?? 'Unknown';
      final senderRole = userData['role'] == 'admin' ? 'admin' : 'resident';

      final messageData = AdminChatMessageModel(
        id: '', // Will be auto-generated
        senderId: senderId,
        senderName: senderName,
        senderRole: senderRole,
        text: text,
        isQuery: isQuery,
        queryType: queryType,
        timestamp: DateTime.now(),
        readBy: [senderId], // Sender has read it
      );

      // Add message to subcollection
      final messageRef = await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .collection(messagesSubcollection)
          .add(messageData.toFirestore());

      // Update chat's last message
      await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .update({
        'lastMessage': text,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageBy': senderRole,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ AdminChatService: Message sent: ${messageRef.id}');
      return messageRef.id;
    } catch (e) {
      print('❌ AdminChatService: Error sending message: $e');
      return null;
    }
  }

  /// Update admin chat status
  Future<bool> updateStatus(String chatId, AdminChatStatus status) async {
    try {
      await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .update({
        'status': status.toString().split('.').last,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('✅ AdminChatService: Status updated to: $status');
      return true;
    } catch (e) {
      print('❌ AdminChatService: Error updating status: $e');
      return false;
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId) async {
    try {
      print('📋 AdminChatService: Marking messages as read...');
      print('   Chat ID: $chatId');

      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        print('❌ Error: No user data found');
        return;
      }

      final userId = userData['id'];
      print('   User ID: $userId');

      // Get unread messages
      print('   Fetching unread messages...');
      final messages = await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .collection(messagesSubcollection)
          .where('senderId', isNotEqualTo: userId)
          .get();

      print('   Found ${messages.docs.length} messages from other users');

      // Mark each as read
      final batch = _firestore.batch();
      int markedCount = 0;
      
      for (var doc in messages.docs) {
        final readBy = List<String>.from(doc.data()['readBy'] ?? []);
        if (!readBy.contains(userId)) {
          batch.update(doc.reference, {
            'readBy': FieldValue.arrayUnion([userId]),
          });
          markedCount++;
        }
      }

      if (markedCount > 0) {
        await batch.commit();
        print('✅ Marked $markedCount messages as read');
      } else {
        print('ℹ️  All messages already marked as read');
      }
    } catch (e) {
      print('❌ AdminChatService: Error marking as read: $e');
    }
  }

  /// Check if resident has open queries (rate limiting)
  Future<int> getOpenQueryCount() async {
    try {
      final userData = await _userDataService.getCurrentUserData();
      
      if (userData == null) {
        return 0;
      }

      final residentId = userData['id'];
      final buildingId = userData['buildingId'];

      if (buildingId == null) {
        return 0;
      }

      final chatId = 'admin_${buildingId}_$residentId';
      
      final chatDoc = await _firestore
          .collection(adminChatsCollection)
          .doc(chatId)
          .get();

      if (!chatDoc.exists) {
        return 0;
      }

      final chat = AdminChatModel.fromFirestore(chatDoc);
      
      return chat.status == AdminChatStatus.open ? 1 : 0;
    } catch (e) {
      print('❌ AdminChatService: Error getting open query count: $e');
      return 0;
    }
  }
}
