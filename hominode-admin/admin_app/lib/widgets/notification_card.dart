import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
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
      margin: EdgeInsets.only(bottom: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon
                Container(
                  width: 40.w,
                  height: 40.h,
                  decoration: BoxDecoration(
                    color: notification.backgroundColor,
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Icon(
                    notification.icon,
                    color: notification.color,
                    size: 20.w,
                  ),
                ),

                SizedBox(width: 12.w),

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
                                fontSize: 14.sp,
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
                          if (notification.priority ==
                                  NotificationPriority.high ||
                              notification.priority ==
                                  NotificationPriority.urgent)
                            Container(
                              width: 8.w,
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: notification.priorityColor,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 4.h),

                      Text(
                        notification.message,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w400,
                          color: notification.isRead
                              ? const Color(0xFF9CA3AF)
                              : const Color(0xFF6B7280),
                        ),
                      ),

                      SizedBox(height: 8.h),

                      Row(
                        children: [
                          Text(
                            notification.formattedTime,
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w400,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),

                          const Spacer(),

                          // Unread indicator
                          if (!notification.isRead)
                            Container(
                              width: 6.w,
                              height: 6.h,
                              decoration: const BoxDecoration(
                                color: Color(0xFF0E4778),
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
                    icon: Icon(
                      Icons.more_vert,
                      color: Color(0xFF9CA3AF),
                      size: 18.w,
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
                        PopupMenuItem(
                          value: 'mark_read',
                          child: Row(
                            children: [
                              Icon(Icons.mark_email_read, size: 18.w),
                              SizedBox(width: 8.w),
                              Text('Mark as read'),
                            ],
                          ),
                        ),
                      if (onDelete != null)
                        PopupMenuItem(
                          value: 'delete',
                          child: Row(
                            children: [
                              Icon(
                                Icons.delete_outline,
                                size: 18.w,
                                color: Colors.red,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Delete',
                                style: TextStyle(color: Colors.red),
                              ),
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
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 4.h),
      padding: EdgeInsets.all(12.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12.r),
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
          borderRadius: BorderRadius.circular(12.r),
          onTap: onTap,
          child: Row(
            children: [
              Container(
                width: 36.w,
                height: 36.h,
                decoration: BoxDecoration(
                  color: notification.backgroundColor,
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  notification.icon,
                  color: notification.color,
                  size: 18.w,
                ),
              ),

              SizedBox(width: 12.w),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      notification.title,
                      style: TextStyle(
                        fontSize: 13.sp,
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

                    SizedBox(height: 2.h),

                    Text(
                      notification.message,
                      style: TextStyle(
                        fontSize: 11.sp,
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
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w400,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),

                  SizedBox(height: 4.h),

                  if (!notification.isRead)
                    Container(
                      width: 6.w,
                      height: 6.h,
                      decoration: const BoxDecoration(
                        color: Color(0xFF0E4778),
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
