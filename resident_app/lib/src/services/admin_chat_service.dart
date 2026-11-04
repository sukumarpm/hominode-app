// Community-scoped Resident -> Admin chat, backed by the shared /chats collection.
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import '../models/admin_chat_model.dart';
import 'user_data_service.dart';

class AdminChatService {
  static final AdminChatService instance = AdminChatService._internal();
  factory AdminChatService() => instance;
  AdminChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final UserDataService _userDataService = UserDataService.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static const String adminChatsCollection = 'chats';
  static const String messagesSubcollection = 'messages';

  AdminChatModel _parseChat(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final categoryName = (data['category'] as String?) ?? 'other';
    final category = QueryCategory.values.firstWhere(
      (value) => value.name == categoryName,
      orElse: () => QueryCategory.other,
    );
    final statusName = (data['status'] as String?) ?? 'open';
    final status = AdminChatStatus.values.firstWhere(
      (value) => value.name == statusName,
      orElse: () => AdminChatStatus.open,
    );
    final now = DateTime.now();
    DateTime? asDate(dynamic value) => value is Timestamp ? value.toDate() : null;
    return AdminChatModel(
      id: doc.id,
      buildingId: data['buildingId'] as String? ?? '',
      adminId: data['adminId'] as String? ?? '',
      adminName: data['adminName'] as String? ?? 'Community Admin',
      adminPhoto: data['adminPhoto'] as String?,
      residentId: data['residentId'] as String? ?? '',
      residentName: data['residentName'] as String? ?? 'Resident',
      residentPhoto: data['residentPhoto'] as String?,
      flatId: data['flatId'] as String? ?? '',
      flatNumber: (data['flatLabel'] ?? data['flatNumber'] ?? 'Unknown').toString(),
      status: status,
      category: category,
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: asDate(data['lastMessageTime']),
      lastMessageBy: data['lastMessageBy'] as String?,
      createdAt: asDate(data['createdAt']) ?? now,
      updatedAt: asDate(data['updatedAt']) ?? now,
    );
  }

  Future<AdminChatModel?> getOrCreateAdminChat({
    required QueryCategory category,
    String? initialMessage,
  }) async {
    try {
      final response = await _functions.httpsCallable('getOrCreateResidentAdminChat').call();
      final chatId = (response.data as Map)['chatId'] as String;
      final ref = _firestore.collection(adminChatsCollection).doc(chatId);
      final chat = await ref.get();
      if (!chat.exists) throw StateError('Chat was not created');
      final result = _parseChat(chat);
      if (initialMessage != null && initialMessage.trim().isNotEmpty) {
        final id = await sendMessage(chatId: chatId, text: initialMessage.trim(), isQuery: true, queryType: category);
        if (id == null) throw StateError('Message could not be sent');
      }
      return result;
    } on FirebaseFunctionsException catch (error) {
      print('Admin chat setup failed: ${error.code}: ${error.message}');
      return null;
    } on FirebaseException catch (error) {
      print('Admin chat Firestore failure: ${error.code}: ${error.message}');
      return null;
    } catch (error) {
      print('Admin chat setup failure: $error');
      return null;
    }
  }

  Future<AdminChatModel?> getExistingAdminChat() async {
    try {
      final uid = _auth.currentUser?.uid;
      final user = await _userDataService.getCurrentUserData();
      final communityId = user?['communityId'] as String?;
      if (uid == null || communityId == null || communityId.isEmpty) return null;
      final ref = _firestore.collection(adminChatsCollection).doc('admin_${communityId}_$uid');
      final doc = await ref.get();
      return doc.exists ? _parseChat(doc) : null;
    } catch (error) {
      print('Admin chat lookup failed: $error');
      return null;
    }
  }

  Stream<List<AdminChatMessageModel>> streamMessages(String chatId) => _firestore
      .collection(adminChatsCollection).doc(chatId).collection(messagesSubcollection)
      .orderBy('timestamp').snapshots().map((snapshot) => snapshot.docs.map((doc) {
        final data = doc.data();
        final categoryName = data['queryType'] as String?;
        final category = categoryName == null ? null : QueryCategory.values.firstWhere(
          (value) => value.name == categoryName, orElse: () => QueryCategory.other);
        return AdminChatMessageModel(
          id: doc.id,
          senderId: data['senderId'] as String? ?? '',
          senderName: data['senderName'] as String? ?? 'Unknown',
          senderRole: data['senderRole'] as String? ?? 'resident',
          text: (data['message'] ?? data['text'] ?? '').toString(),
          isQuery: data['isQuery'] == true,
          queryType: category,
          timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
          readBy: List<String>.from(data['readBy'] ?? const []),
        );
      }).toList());

  Future<String?> sendMessage({
    required String chatId,
    required String text,
    bool isQuery = false,
    QueryCategory? queryType,
  }) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null || text.trim().isEmpty) return null;
      final rand = Random.secure();
      final submissionId = List.generate(
        20, (_) => rand.nextInt(256).toRadixString(16).padLeft(2, '0'),
      ).join();
      final response = await _functions.httpsCallable('sendModeratedAdminChatMessage').call({
        'chatId': chatId,
        'message': text.trim(),
        'submissionId': submissionId,
        'isQuery': isQuery,
        'queryType': queryType?.name,
      });
      return (response.data as Map)['messageId'] as String?;
    } on FirebaseFunctionsException catch (error) {
      throw StateError(error.message ?? 'Unable to send message.');
    }

  }

  Future<bool> updateStatus(String chatId, AdminChatStatus status) async {
    try {
      await _firestore.collection(adminChatsCollection).doc(chatId).update({
        'status': status.name, 'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } catch (error) {
      print('Admin chat status update failed: $error');
      return false;
    }
  }

  Future<void> markAsRead(String chatId) async {
    try {
      final uid = _auth.currentUser?.uid;
      if (uid == null) return;
      final messages = await _firestore.collection(adminChatsCollection).doc(chatId)
        .collection(messagesSubcollection).orderBy('timestamp', descending: true).limit(100).get();
      final batch = _firestore.batch();
      var pending = 0;
      for (final message in messages.docs) {
        final data = message.data();
        if (data['senderId'] == uid || data['isRead'] == true) continue;
        batch.update(message.reference, {
          'isRead': true,
          'readBy': FieldValue.arrayUnion([uid]),
        });
        pending++;
      }
      if (pending > 0) await batch.commit();
    } catch (error) {
      print('Admin chat mark read failed: $error');
    }
  }

  Future<int> getOpenQueryCount() async {
    final chat = await getExistingAdminChat();
    return chat?.status == AdminChatStatus.open ? 1 : 0;
  }
}
