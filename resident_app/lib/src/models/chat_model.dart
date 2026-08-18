// lib/src/models/chat_model.dart
// Chat and Message models for Firestore

import 'package:cloud_firestore/cloud_firestore.dart';

/// Chat model - represents a conversation
class ChatModel {
  final String id;
  final String communityId;
  final String title;
  final String? subtitle;
  final List<String> participantIds;
  final Map<String, String>? participantNames; // Map of userId -> name
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final String? iconUrl;
  final String? iconName;
  final String? iconBg;
  final bool isGroup;
  final String? buildingId;
  final String? flatId;
  final String? type;
  final DateTime createdAt;
  final DateTime updatedAt;

  ChatModel({
    required this.id,
    this.communityId = '',
    required this.title,
    this.subtitle,
    required this.participantIds,
    this.participantNames,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.iconUrl,
    this.iconName,
    this.iconBg,
    this.isGroup = false,
    this.buildingId,
    this.flatId,
    this.type,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ChatModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatModel(
      id: doc.id,
      communityId: data['communityId'] as String? ?? '',
      title: data['title'] ?? 'Unknown',
      subtitle: data['subtitle'],
      participantIds: List<String>.from(data['participantIds'] ?? []),
      participantNames: data['participantNames'] != null
          ? Map<String, String>.from(data['participantNames'] as Map)
          : null,
      lastMessage: data['lastMessage'],
      lastMessageTime: (data['lastMessageTime'] as Timestamp?)?.toDate(),
      unreadCount: data['unreadCount'] ?? 0,
      iconUrl: data['iconUrl'],
      iconName: data['iconName'],
      iconBg: data['iconBg'],
      isGroup: data['isGroup'] ?? false,
      buildingId: data['buildingId'],
      flatId: data['flatId'],
      type: data['type'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'communityId': communityId,
      'subtitle': subtitle,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime != null
          ? Timestamp.fromDate(lastMessageTime!)
          : null,
      'unreadCount': unreadCount,
      'iconUrl': iconUrl,
      'iconName': iconName,
      'iconBg': iconBg,
      'isGroup': isGroup,
      'buildingId': buildingId,
      'flatId': flatId,
      'type': type,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}

/// Message model - represents a single message in a chat
class MessageModel {
  final String id;
  final String communityId;
  final String chatId;
  final String senderId;
  final String senderName;
  final String? senderPhotoUrl;
  final String text;
  final DateTime timestamp;
  final MessageStatus status;
  final List<String> readBy;
  final String? imageUrl;
  final String? fileUrl;
  final String? fileName;

  MessageModel({
    required this.id,
    this.communityId = '',
    required this.chatId,
    required this.senderId,
    required this.senderName,
    this.senderPhotoUrl,
    required this.text,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.readBy = const [],
    this.imageUrl,
    this.fileUrl,
    this.fileName,
  });

  factory MessageModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return MessageModel(
      id: doc.id,
      communityId: data['communityId'] as String? ?? '',
      chatId: data['chatId'] ?? '',
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderPhotoUrl: data['senderPhotoUrl'],
      text: data['text'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: MessageStatus.values.firstWhere(
        (e) => e.toString() == 'MessageStatus.${data['status']}',
        orElse: () => MessageStatus.sent,
      ),
      readBy: List<String>.from(data['readBy'] ?? []),
      imageUrl: data['imageUrl'],
      fileUrl: data['fileUrl'],
      fileName: data['fileName'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'communityId': communityId,
      'senderId': senderId,
      'senderName': senderName,
      'senderPhotoUrl': senderPhotoUrl,
      'text': text,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.toString().split('.').last,
      'readBy': readBy,
      'imageUrl': imageUrl,
      'fileUrl': fileUrl,
      'fileName': fileName,
    };
  }

  MessageModel copyWith({MessageStatus? status, List<String>? readBy}) {
    return MessageModel(
      id: id,
      chatId: chatId,
      senderId: senderId,
      senderName: senderName,
      senderPhotoUrl: senderPhotoUrl,
      text: text,
      timestamp: timestamp,
      status: status ?? this.status,
      readBy: readBy ?? this.readBy,
      imageUrl: imageUrl,
      fileUrl: fileUrl,
      fileName: fileName,
    );
  }
}

/// Message status enum
enum MessageStatus { sending, sent, delivered, read, failed }

/// Chat request status enum
enum ChatRequestStatus { pending, accepted, rejected }

/// Chat request model
class ChatRequestModel {
  final String id;
  final String senderId;
  final String senderName;
  final String? senderPhoto;
  final String receiverId;
  final String receiverName;
  final String? receiverPhoto;
  final String flatId;
  final ChatRequestStatus status;
  final DateTime createdAt;
  final DateTime? respondedAt;

  ChatRequestModel({
    required this.id,
    required this.senderId,
    required this.senderName,
    this.senderPhoto,
    required this.receiverId,
    required this.receiverName,
    this.receiverPhoto,
    required this.flatId,
    required this.status,
    required this.createdAt,
    this.respondedAt,
  });

  factory ChatRequestModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ChatRequestModel(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? 'Unknown',
      senderPhoto: data['senderPhoto'],
      receiverId: data['receiverId'] ?? '',
      receiverName: data['receiverName'] ?? 'Unknown',
      receiverPhoto: data['receiverPhoto'],
      flatId: data['flatId'] ?? '',
      status: ChatRequestStatus.values.firstWhere(
        (e) => e.toString() == 'ChatRequestStatus.${data['status']}',
        orElse: () => ChatRequestStatus.pending,
      ),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondedAt: (data['respondedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'senderId': senderId,
      'senderName': senderName,
      'senderPhoto': senderPhoto,
      'receiverId': receiverId,
      'receiverName': receiverName,
      'receiverPhoto': receiverPhoto,
      'flatId': flatId,
      'status': status.toString().split('.').last,
      'createdAt': Timestamp.fromDate(createdAt),
      'respondedAt': respondedAt != null
          ? Timestamp.fromDate(respondedAt!)
          : null,
    };
  }
}
