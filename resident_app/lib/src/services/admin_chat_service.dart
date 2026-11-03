// Resident's community Admin conversation uses the canonical chats collection.
// Creation, Admin selection, and sending are trusted server-side operations.
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../models/admin_chat_model.dart';

class AdminChatService {
  static final AdminChatService instance = AdminChatService._internal();
  factory AdminChatService() => instance;
  AdminChatService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseFunctions _functions =
      FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  static const String adminChatsCollection = 'chats';
  static const String messagesSubcollection = 'messages';

  String _newRequestId() {
    final random = Random.secure();
    final nonce = List<int>.generate(16, (_) => random.nextInt(256));
    final suffix = nonce.map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    return '${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> data) async {
    final result = await _functions.httpsCallable('createResidentAdminChat').call(data);
    final raw = result.data;
    if (raw is! Map) {
      throw StateError('Invalid Admin chat response.');
    }
    return Map<String, dynamic>.from(raw);
  }

  Future<AdminChatModel?> _loadChat(Object? id) async {
    if (id is! String || id.isEmpty) return null;
    final doc = await _firestore.collection(adminChatsCollection).doc(id).get();
    return doc.exists ? AdminChatModel.fromFirestore(doc) : null;
  }

  /// A quick query creates or reuses the authorized community Admin conversation.
  Future<AdminChatModel?> getOrCreateAdminChat({
    required QueryCategory category,
    String? initialMessage,
  }) async {
    final message = initialMessage?.trim() ?? '';
    if (message.isEmpty) throw ArgumentError('A message is required.');
    final result = await _invoke({
      'action': 'send',
      'category': category.name,
      'message': message,
      'isQuery': true,
      'requestId': _newRequestId(),
    });
    final chat = await _loadChat(result['chatId']);
    if (chat == null) throw StateError('The Admin chat was not found.');
    return chat;
  }

  /// Do not enumerate private Admin profiles or use a placeholder Admin ID.
  Future<AdminChatModel?> getExistingAdminChat() async {
    final result = await _invoke({'action': 'lookup'});
    return _loadChat(result['chatId']);
  }

  Stream<List<AdminChatMessageModel>> streamMessages(String chatId) {
    return _firestore
        .collection(adminChatsCollection)
        .doc(chatId)
        .collection(messagesSubcollection)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map(AdminChatMessageModel.fromFirestore)
            .toList(growable: false));
  }

  /// Follow-up messages share the same trusted writer and collection as Admin.
  Future<String?> sendMessage({
    required String chatId,
    required String text,
    bool isQuery = false,
    QueryCategory? queryType,
  }) async {
    final message = text.trim();
    if (message.isEmpty) return null;
    final current = await _loadChat(chatId);
    if (current == null) throw StateError('The Admin chat is unavailable.');
    final result = await _invoke({
      'action': 'send',
      'category': (queryType ?? current.category).name,
      'message': message,
      'isQuery': isQuery,
      'requestId': _newRequestId(),
    });
    if (result['chatId'] != chatId) {
      throw StateError('The community Admin conversation changed.');
    }
    return chatId;
  }

  Future<bool> updateStatus(String chatId, AdminChatStatus status) async {
    try {
      await _firestore.collection(adminChatsCollection).doc(chatId).update({
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      return true;
    } on FirebaseException {
      rethrow;
    }
  }

  Future<void> markAsRead(String chatId) async {
    // Reconciliation of per-user read receipts needs its own scoped workflow.
    // The Resident never modifies another participant's message content.
  }

  Future<int> getOpenQueryCount() async {
    final chat = await getExistingAdminChat();
    return chat?.status == AdminChatStatus.open ? 1 : 0;
  }
}
