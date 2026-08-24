import 'package:flutter/material.dart';
import '../models/notification_models.dart';

class NotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAsRead;
  final VoidCallback? onDelete;

  const NotificationCard({
    super.key,
    required this.notification,
    this.onTap,
    this.onMarkAsRead,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: notification.isRead 
              ? Colors.transparent 
              : notification.priorityColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: notification.backgroundColor,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 20,
                  ),
                ),
                
                const SizedBox(width: 12),
                
                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              notification.title,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: notification.isRead 
                                    ? FontWeight.w500 
                                    : FontWeight.w600,
                                color: notification.isRead 
                                    ? const Color(0xFF6B7280) 
                                    : const Color(0xFF111827),
                              ),
                            ),
                          ),
                          
                          // Priority indicator
                          if (notification.priority == NotificationPriority.high ||
                              notification.priority == NotificationPriority.urgent)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: notification.priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      
                      const SizedBox(height: 4),
                      
                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w400,
                          color: notification.isRead 
                              ? const Color(0xFF9CA3AF) 
                              : const Color(0xFF6B7280),
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      Row(
                        children: [
                          Text(
                            notification.formattedTime,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                          
                          const Spacer(),
                          
                          // Unread indicator
                          if (!notification.isRead)
                            Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2563EB),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                
                // Actions menu
                if (onMarkAsRead != null || onDelete != null)
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Color(0xFF9CA3AF),
                      size: 18,
                    ),
                    onSelected: (value) {
                      switch (value) {
                        case 'mark_read':
                          onMarkAsRead?.call();
                          break;
                        case 'delete':
                          onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => [
                      if (!notification.isRead && onMarkAsRead != null)
                        const PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_read, size: 18),
                              SizedBox(width: 8),
                              Text('Mark as read'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        const PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(Icons.delete_outline, size: 18, color: Colors.red),
                              SizedBox(width: 8),
                              Text('Delete', style: TextStyle(color: Colors.red)),
                            ],
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Compact notification card for dashboard or quick views
class CompactNotificationCard extends StatelessWidget {
  final NotificationModel notification;
  final VoidCallback? onTap;

  const CompactNotificationCard({
    super.key,
    required this.notification,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: notification.isRead 
            ? null 
            : Border.all(
                color: notification.priorityColor.withOpacity(0.2),
                width: 1,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: notification.backgroundColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 18,
                ),
              ),
              
              const SizedBox(width: 12),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: notification.isRead 
                            ? FontWeight.w500 
                            : FontWeight.w600,
                        color: notification.isRead 
                            ? const Color(0xFF6B7280) 
                            : const Color(0xFF111827),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    const SizedBox(height: 2),
                    
                    Text(
                      notification.message,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w400,
                        color: Color(0xFF9CA3AF),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    notification.formattedTime,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                  
                  const SizedBox(height: 4),
                  
                  if (!notification.isRead)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Color(0xFF2563EB),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}