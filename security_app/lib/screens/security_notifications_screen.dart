import 'package:flutter/material.dart';
import 'package:hominode_notifications/hominode_notifications.dart';
import 'package:hominode_sos/hominode_sos.dart';
import 'package:intl/intl.dart';

import '../services/security_inbox_service.dart';
import '../services/security_notification_router.dart';
import '../utils/app_colors.dart';

class SecurityNotificationsScreen extends StatefulWidget {
  const SecurityNotificationsScreen({
    super.key,
    this.inbox,
    this.onNotificationTap,
  });
  final SecurityInbox? inbox;
  final Future<void> Function(HominodeNotificationPayload)? onNotificationTap;

  @override
  State<SecurityNotificationsScreen> createState() =>
      _SecurityNotificationsScreenState();
}

class _SecurityNotificationsScreenState
    extends State<SecurityNotificationsScreen> {
  late final SecurityInbox _inbox = widget.inbox ?? SecurityInboxService();
  late Stream<List<SecurityInboxNotification>> _stream = _inbox.watch();

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      title: const Text('Notifications'),
      backgroundColor: AppColors.primaryTeal,
      foregroundColor: Colors.white,
    ),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 840),
          child: StreamBuilder<List<SecurityInboxNotification>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(
                    semanticsLabel: 'Loading notifications',
                  ),
                );
              }
              if (snapshot.hasError) {
                return Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          securityInboxError(snapshot.error!),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () => setState(() {
                            _stream = _inbox.watch();
                          }),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                );
              }
              final rows = snapshot.data ?? [];
              if (rows.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text('No notifications yet.'),
                  ),
                );
              }
              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: rows.length,
                separatorBuilder: (_, _) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _NotificationTile(
                  key: ValueKey(rows[index].id),
                  notification: rows[index],
                  inbox: _inbox,
                  onOpen:
                      widget.onNotificationTap ??
                      SecurityNotificationRouter.handle,
                ),
              );
            },
          ),
        ),
      ),
    ),
  );
}

class _NotificationTile extends StatefulWidget {
  const _NotificationTile({
    super.key,
    required this.notification,
    required this.inbox,
    required this.onOpen,
  });
  final SecurityInboxNotification notification;
  final SecurityInbox inbox;
  final Future<void> Function(HominodeNotificationPayload) onOpen;
  @override
  State<_NotificationTile> createState() => _NotificationTileState();
}

class _NotificationTileState extends State<_NotificationTile> {
  bool _busy = false, _confirmedRead = false;
  String? _error;
  Future<void> _perform(
    Future<void> Function() action, {
    bool markRead = false,
  }) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      if (mounted && markRead) setState(() => _confirmedRead = true);
    } catch (error) {
      if (mounted) setState(() => _error = securityInboxError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notification = widget.notification;
    final sosId = sosAlertIdFromNotification(notification.data);
    final read = notification.isRead || _confirmedRead;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Icon(
                  sosId == null ? Icons.notifications_outlined : Icons.sos,
                  color: sosId == null
                      ? AppColors.primaryTeal
                      : AppColors.errorRed,
                ),
                Text(
                  read ? 'Read' : 'Unread',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (sosId != null) const Text('Emergency SOS'),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              notification.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(notification.message),
            const SizedBox(height: 12),
            Text(
              notification.createdAt == null
                  ? 'Date unavailable'
                  : DateFormat.yMMMd().add_jm().format(notification.createdAt!),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (!read)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            () => widget.inbox.markRead(notification),
                            markRead: true,
                          ),
                    child: Text(_busy ? 'Please wait…' : 'Mark as read'),
                  ),
                if (sosId != null)
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => _perform(
                            () => widget.onOpen(
                              HominodeNotificationPayload(
                                type: 'notification',
                                entityId: notification.id,
                                communityId:
                                    notification.data['communityId'] as String,
                              ),
                            ),
                          ),
                    child: const Text('Open SOS alert'),
                  ),
              ],
            ),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.errorRed)),
          ],
        ),
      ),
    );
  }
}
