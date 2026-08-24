import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'models/notification_models.dart';
import 'services/notification_service.dart';
import 'widgets/standard_header.dart';
import 'widgets/notification_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  NotificationType? _selectedFilter;
  bool _showOnlyUnread = false;

  @override
  void initState() {
    super.initState();
    _notificationService.initializeNotifications();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          StandardHeader(
            title: 'Notifications',
            showBackButton: true,
            actionWidget: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Mark all as read button
                GestureDetector(
                  onTap: _notificationService.unreadCount > 0
                      ? () {
                          _notificationService.markAllAsRead();
                          setState(() {});
                        }
                      : null,
                  child: Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.done_all,
                      color: _notificationService.unreadCount > 0
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      size: 20.w,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                // Filter menu
                PopupMenuButton<String>(
                  icon: Container(
                    width: 40.w,
                    height: 40.h,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 20.w,
                    ),
                  ),
                  onSelected: (value) {
                    setState(() {
                      if (value == 'all') {
                        _selectedFilter = null;
                        _showOnlyUnread = false;
                      } else if (value == 'unread') {
                        _selectedFilter = null;
                        _showOnlyUnread = true;
                      } else {
                        _selectedFilter = NotificationType.values.firstWhere(
                          (type) => type.name == value,
                        );
                        _showOnlyUnread = false;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.all_inclusive, size: 20.w),
                          SizedBox(width: 8.w),
                          Text('All Notifications'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'unread',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_unread, size: 20.w),
                          SizedBox(width: 8.w),
                          Text('Unread Only'),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    ...NotificationType.values.map(
                      (type) => PopupMenuItem(
                        value: type.name,
                        child: Row(
                          children: [
                            Icon(_getTypeIcon(type), size: 20.w),
                            SizedBox(width: 8.w),
                            Text(_getTypeLabel(type)),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 12.h),
                _buildNotificationHeader(),
                SizedBox(height: 16.h),
                _buildFilterChips(),
                SizedBox(height: 16.h),
              ],
            ),
          ),

          // Notifications list
          _buildNotificationsList(),

          // Bottom padding
          SliverToBoxAdapter(child: SizedBox(height: 80.h)),
        ],
      ),
    );
  }

  Widget _buildNotificationHeader() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          Container(
            width: 44.w,
            height: 44.h,
            decoration: BoxDecoration(
              color: const Color(0xFF0E4778).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.notifications_active,
              color: Color(0xFF0E4778),
              size: 24.w,
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notification Center',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  '${_getFilteredNotifications().length} notifications • ${_notificationService.unreadCount} unread',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.w400,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              'All',
              _selectedFilter == null && !_showOnlyUnread,
              () {
                setState(() {
                  _selectedFilter = null;
                  _showOnlyUnread = false;
                });
              },
            ),
            SizedBox(width: 8.w),
            _buildFilterChip('Unread', _showOnlyUnread, () {
              setState(() {
                _selectedFilter = null;
                _showOnlyUnread = true;
              });
            }),
            SizedBox(width: 8.w),
            ...NotificationType.values.map(
              (type) => Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: _buildFilterChip(
                  _getTypeLabel(type),
                  _selectedFilter == type,
                  () {
                    setState(() {
                      _selectedFilter = type;
                      _showOnlyUnread = false;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0E4778) : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF0E4778)
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    final notifications = _getFilteredNotifications();

    if (notifications.isEmpty) {
      return SliverFillRemaining(child: _buildEmptyState());
    }

    final groupedNotifications = _getGroupedFilteredNotifications();

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final entry = groupedNotifications.entries.elementAt(index);
        final dateKey = entry.key;
        final dayNotifications = entry.value;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date header
            Padding(
              padding: EdgeInsets.fromLTRB(16.w, 16.h, 16.w, 8.h),
              child: Text(
                dateKey,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                ),
              ),
            ),

            // Notifications for this date
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Column(
                children: dayNotifications
                    .map(
                      (notification) => Padding(
                        padding: EdgeInsets.only(bottom: 8.h),
                        child: NotificationCard(
                          notification: notification,
                          onTap: () => _handleNotificationTap(notification),
                          onMarkAsRead: () {
                            _notificationService.markAsRead(notification.id);
                            setState(() {});
                          },
                          onDelete: () {
                            _notificationService.deleteNotification(
                              notification.id,
                            );
                            setState(() {});
                          },
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        );
      }, childCount: groupedNotifications.length),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80.w,
            height: 80.h,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(40.r),
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 40.w,
              color: Color(0xFF9CA3AF),
            ),
          ),

          SizedBox(height: 16.h),

          Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),

          SizedBox(height: 8.h),

          Text(
            _selectedFilter != null
                ? 'No ${_getTypeLabel(_selectedFilter!).toLowerCase()} notifications'
                : _showOnlyUnread
                ? 'No unread notifications'
                : 'You\'re all caught up!',
            style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  List<NotificationModel> _getFilteredNotifications() {
    var notifications = _notificationService.notifications;

    if (_selectedFilter != null) {
      notifications = notifications
          .where((n) => n.type == _selectedFilter)
          .toList();
    }

    if (_showOnlyUnread) {
      notifications = notifications.where((n) => !n.isRead).toList();
    }

    return notifications;
  }

  Map<String, List<NotificationModel>> _getGroupedFilteredNotifications() {
    final notifications = _getFilteredNotifications();
    final Map<String, List<NotificationModel>> grouped = {};
    final now = DateTime.now();

    for (final notification in notifications) {
      final difference = now.difference(notification.timestamp);
      String dateKey;

      if (difference.inDays == 0) {
        dateKey = 'Today';
      } else if (difference.inDays == 1) {
        dateKey = 'Yesterday';
      } else if (difference.inDays < 7) {
        dateKey = '${difference.inDays} days ago';
      } else {
        dateKey =
            '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}';
      }

      if (!grouped.containsKey(dateKey)) {
        grouped[dateKey] = [];
      }
      grouped[dateKey]!.add(notification);
    }

    return grouped;
  }

  void _handleNotificationTap(NotificationModel notification) {
    // Mark as read when tapped
    if (!notification.isRead) {
      _notificationService.markAsRead(notification.id);
      setState(() {});
    }

    // Handle navigation based on notification type
    switch (notification.type) {
      case NotificationType.visitor:
        Navigator.pushNamed(context, '/visitor_management');
        break;
      case NotificationType.complaint:
        Navigator.pushNamed(context, '/complaints');
        break;
      case NotificationType.payment:
        Navigator.pushNamed(context, '/billing');
        break;
      case NotificationType.maintenance:
        // Navigate to maintenance screen when available
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Maintenance screen coming soon')),
        );
        break;
      case NotificationType.announcement:
        Navigator.pushNamed(context, '/events');
        break;
      case NotificationType.event:
        Navigator.pushNamed(context, '/events');
        break;
      case NotificationType.security:
        // Navigate to security screen when available
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Security screen coming soon')),
        );
        break;
      case NotificationType.general:
        // Handle general notifications
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Notification: ${notification.title}')),
        );
        break;
    }
  }

  IconData _getTypeIcon(NotificationType type) {
    switch (type) {
      case NotificationType.visitor:
        return Icons.person_add;
      case NotificationType.complaint:
        return Icons.report_problem;
      case NotificationType.payment:
        return Icons.payment;
      case NotificationType.maintenance:
        return Icons.build;
      case NotificationType.announcement:
        return Icons.campaign;
      case NotificationType.event:
        return Icons.event;
      case NotificationType.security:
        return Icons.security;
      case NotificationType.general:
        return Icons.notifications;
    }
  }

  String _getTypeLabel(NotificationType type) {
    switch (type) {
      case NotificationType.visitor:
        return 'Visitors';
      case NotificationType.complaint:
        return 'Complaints';
      case NotificationType.payment:
        return 'Payments';
      case NotificationType.maintenance:
        return 'Maintenance';
      case NotificationType.announcement:
        return 'Announcements';
      case NotificationType.event:
        return 'Events';
      case NotificationType.security:
        return 'Security';
      case NotificationType.general:
        return 'General';
    }
  }
}
