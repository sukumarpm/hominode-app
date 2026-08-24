enum ChatType { individual, group }

class ChatMessage {
  final String id;
  final String senderId;
  final String senderName;
  final String senderType; // 'admin', 'resident', 'staff'
  final String message;
  final DateTime timestamp;
  final String? flatNumber;

  ChatMessage({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.senderType,
    required this.message,
    required this.timestamp,
    this.flatNumber,
  });
}

class ChatConversation {
  final String id;
  final String name;
  final String? flatNumber;
  final String lastMessage;
  final DateTime timestamp;
  final int unreadCount;
  final bool isOnline;
  final ChatType chatType;
  final int? memberCount;

  ChatConversation({
    required this.id,
    required this.name,
    this.flatNumber,
    required this.lastMessage,
    required this.timestamp,
    required this.unreadCount,
    required this.isOnline,
    required this.chatType,
    this.memberCount,
  });
}

class ResidentContact {
  final String id;
  final String name;
  final String flatNumber;
  final bool isOnline;
  final bool hasExistingChat;

  ResidentContact({
    required this.id,
    required this.name,
    required this.flatNumber,
    required this.isOnline,
    required this.hasExistingChat,
  });
}

class GroupChat {
  final String id;
  final String name;
  final int memberCount;
  final String description;
  final bool isActive;

  GroupChat({
    required this.id,
    required this.name,
    required this.memberCount,
    required this.description,
    required this.isActive,
  });
}