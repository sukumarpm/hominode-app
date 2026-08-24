import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final AdminService _adminService = AdminService();
  final String _chatsCollection = 'chats';
  final String _messagesCollection = 'messages';

  // Get all chat conversations for admin
  Stream<List<ChatConversationModel>> getChatConversations() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    print('ChatService: Fetching conversations for admin: $adminId');

    return _firestore
        .collection(_chatsCollection)
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .where('participants', arrayContains: adminId)
        .orderBy('lastMessageTime', descending: true)
        .snapshots()
        .map((snapshot) {
          print('ChatService: Found ${snapshot.docs.length} conversations');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ChatConversationModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  // Get messages for a specific chat
  Stream<List<ChatMessageModel>> getChatMessages(String chatId) {
    print('ChatService: Fetching messages for chat: $chatId');

    return _firestore
        .collection(_chatsCollection)
        .doc(chatId)
        .collection(_messagesCollection)
        .orderBy('timestamp', descending: true)
        .limit(100)
        .snapshots()
        .map((snapshot) {
          print('ChatService: Found ${snapshot.docs.length} messages');
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ChatMessageModel.fromFirestore(doc.id, data);
          }).toList();
        });
  }

  // Send a message
  Future<void> sendMessage({
    required String chatId,
    required String message,
    String? imageUrl,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final adminProfile = await _adminService.getAdminProfile();
      final senderName = adminProfile?['name'] ?? 'Admin';

      print('ChatService: Sending message to chat: $chatId');

      // Add message to messages subcollection
      await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .add({
            'senderId': adminId,
            'senderName': senderName,
            'senderRole': 'admin',
            'communityId': _adminService.requireCurrentCommunityId(),
            'message': message,
            'imageUrl': imageUrl,
            'timestamp': FieldValue.serverTimestamp(),
            'isRead': false,
          });

      // Update chat document with last message info
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': adminId,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('ChatService: Message sent successfully');
    } catch (e) {
      print('ChatService ERROR: Failed to send message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  // Create or get existing chat with a resident
  Future<String> createOrGetChat({
    required String residentId,
    required String residentName,
    required String flatLabel,
  }) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) throw Exception('Admin not logged in');

      final adminProfile = await _adminService.getAdminProfile();
      final buildingId = adminProfile?['buildingId'] ?? '';
      final buildingName = adminProfile?['buildingName'] ?? '';

      print('ChatService: Creating/getting chat with resident: $residentId');

      // Check if chat already exists
      final existingChats = await _firestore
          .collection(_chatsCollection)
          .where(
            'communityId',
            isEqualTo: _adminService.requireCurrentCommunityId(),
          )
          .where('participants', arrayContains: adminId)
          .where('chatType', isEqualTo: 'individual')
          .get();

      for (var doc in existingChats.docs) {
        final participants = List<String>.from(doc.data()['participants']);
        if (participants.contains(residentId)) {
          print('ChatService: Found existing chat: ${doc.id}');
          return doc.id;
        }
      }

      // Create new chat
      print('ChatService: Creating new chat');
      final chatDoc = await _firestore.collection(_chatsCollection).add({
        'chatType': 'individual',
        'participants': [adminId, residentId],
        'participantNames': {
          adminId: adminProfile?['name'] ?? 'Admin',
          residentId: residentName,
        },
        'participantRoles': {adminId: 'admin', residentId: 'resident'},
        'residentId': residentId,
        'residentName': residentName,
        'flatLabel': flatLabel,
        'buildingId': buildingId,
        'buildingName': buildingName,
        'adminId': adminId,
        'communityId': _adminService.requireCurrentCommunityId(),
        'lastMessage': '',
        'lastMessageTime': FieldValue.serverTimestamp(),
        'lastMessageSenderId': '',
        'unreadCount': {adminId: 0, residentId: 0},
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print('ChatService: Chat created with ID: ${chatDoc.id}');
      return chatDoc.id;
    } catch (e) {
      print('ChatService ERROR: Failed to create/get chat: $e');
      throw Exception('Failed to create/get chat: $e');
    }
  }

  // Mark messages as read
  Future<void> markMessagesAsRead(String chatId) async {
    try {
      final adminId = _adminService.getCurrentAdminId();
      if (adminId == null) return;

      final messages = await _firestore
          .collection(_chatsCollection)
          .doc(chatId)
          .collection(_messagesCollection)
          .where('senderId', isNotEqualTo: adminId)
          .where('isRead', isEqualTo: false)
          .get();

      final batch = _firestore.batch();
      for (var doc in messages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }

      // Update unread count
      batch.update(_firestore.collection(_chatsCollection).doc(chatId), {
        'unreadCount.$adminId': 0,
      });

      await batch.commit();
      print('ChatService: Messages marked as read');
    } catch (e) {
      print('ChatService ERROR: Failed to mark messages as read: $e');
    }
  }

  // Get all residents for chat
  Stream<List<ResidentContactModel>> getResidents() {
    final adminId = _adminService.getCurrentAdminId();
    if (adminId == null) return Stream.value([]);

    return _firestore
        .collection('users')
        .where('role', isEqualTo: 'resident')
        .where(
          'communityId',
          isEqualTo: _adminService.requireCurrentCommunityId(),
        )
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            final data = doc.data();
            return ResidentContactModel(
              id: doc.id,
              name: data['name'] ?? '',
              flatLabel: data['flatLabel'] ?? '',
              phone: data['phone'] ?? '',
              email: data['email'],
              isOnline: false, // TODO: Implement online status
            );
          }).toList();
        });
  }
}

// Chat Conversation Model
class ChatConversationModel {
  final String id;
  final String chatType; // 'individual' or 'group'
  final List<String> participants;
  final Map<String, String> participantNames;
  final String residentId;
  final String residentName;
  final String flatLabel;
  final String buildingId;
  final String buildingName;
  final String lastMessage;
  final DateTime? lastMessageTime;
  final String lastMessageSenderId;
  final Map<String, int> unreadCount;
  final DateTime? createdAt;

  ChatConversationModel({
    required this.id,
    required this.chatType,
    required this.participants,
    required this.participantNames,
    required this.residentId,
    required this.residentName,
    required this.flatLabel,
    required this.buildingId,
    required this.buildingName,
    required this.lastMessage,
    this.lastMessageTime,
    required this.lastMessageSenderId,
    required this.unreadCount,
    this.createdAt,
  });

  factory ChatConversationModel.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    return ChatConversationModel(
      id: id,
      chatType: data['chatType'] ?? 'individual',
      participants: List<String>.from(data['participants'] ?? []),
      participantNames: Map<String, String>.from(
        data['participantNames'] ?? {},
      ),
      residentId: data['residentId'] ?? '',
      residentName: data['residentName'] ?? '',
      flatLabel: data['flatLabel'] ?? '',
      buildingId: data['buildingId'] ?? '',
      buildingName: data['buildingName'] ?? '',
      lastMessage: data['lastMessage'] ?? '',
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] ?? '',
      unreadCount: Map<String, int>.from(
        (data['unreadCount'] as Map?)?.map(
              (k, v) => MapEntry(k.toString(), v as int),
            ) ??
            {},
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  String getFormattedTime() {
    if (lastMessageTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(lastMessageTime!);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastMessageTime!.day}/${lastMessageTime!.month}/${lastMessageTime!.year}';
    }
  }
}

// Chat Message Model
class ChatMessageModel {
  final String id;
  final String senderId;
  final String senderName;
  final String senderRole; // 'admin' or 'resident'
  final String message;
  final String? imageUrl;
  final DateTime? timestamp;
  final bool isRead;

  ChatMessageModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderRole,
    required this.message,
    this.imageUrl,
    this.timestamp,
    required this.isRead,
  });

  factory ChatMessageModel.fromFirestore(String id, Map<String, dynamic> data) {
    return ChatMessageModel(
      id: id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      senderRole: data['senderRole'] ?? 'resident',
      message: data['message'] ?? '',
      imageUrl: data['imageUrl'],
      timestamp: (data['timestamp'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] ?? false,
    );
  }

  bool get isSentByAdmin => senderRole == 'admin';
}

// Resident Contact Model
class ResidentContactModel {
  final String id;
  final String name;
  final String flatLabel;
  final String phone;
  final String? email;
  final bool isOnline;

  ResidentContactModel({
    required this.id,
    required this.name,
    required this.flatLabel,
    required this.phone,
    this.email,
    required this.isOnline,
  });
}
