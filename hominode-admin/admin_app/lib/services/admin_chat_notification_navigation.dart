import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../resident_chat_screen.dart';
import 'admin_tenant_context.dart';

/// Opens a moderated Resident-Admin chat only for an authorized current Admin.
class AdminChatNotificationNavigation {
  const AdminChatNotificationNavigation._();

  static Future<bool> open(
    BuildContext context, {
    required String chatId,
    required String communityId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || communityId != AdminTenantContext.instance.communityId ||
        chatId.isEmpty || chatId.contains('/')) return false;

    final chat = await FirebaseFirestore.instance
        .collection('chats').doc(chatId)
        .get(const GetOptions(source: Source.server));
    final data = chat.data();
    final members = data?['participants'];
    if (!chat.exists || data?['communityId'] != communityId ||
        data?['adminId'] != user.uid ||
        members is! List || !members.contains(user.uid) ||
        data?['residentId'] is! String ||
        !members.contains(data!['residentId'])) {
      return false;
    }
    if (!context.mounted) return false;
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ResidentChatScreen(chatId: chatId),
      ),
    );
    return true;
  }
}
