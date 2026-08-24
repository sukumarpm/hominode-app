import 'package:flutter/material.dart';
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
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.done_all,
                      color: _notificationService.unreadCount > 0
                          ? Colors.white
                          : Colors.white.withOpacity(0.5),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // Filter menu
                PopupMenuButton<String>(
                  icon: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.filter_list,
                      color: Colors.white,
                      size: 20,
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
                        _selectedFilter = NotificationType.values
                            .firstWhere((type) => type.name == value);
                        _showOnlyUnread = false;
                      }
                    });
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'all',
                      child: Row(
                        children: [
                          Icon(Icons.all_inclusive, size: 20),
                          SizedBox(width: 8),
                          Text('All Notifications'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'unread',
                      child: Row(
                        children: [
                          Icon(Icons.mark_email_unread, size: 20),
                          SizedBox(width: 8),
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
                            Icon(_getTypeIcon(type), size: 20),
                            const SizedBox(width: 8),
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
                const SizedBox(height: 12),
                _buildNotificationHeader(),
                const SizedBox(height: 16),
                _buildFilterChips(),
                const SizedBox(height: 16),
              ],
            ),
          ),
          
          // Notifications list
          _buildNotificationsList(),
          
          // Bottom padding
          const SliverToBoxAdapter(
            child: SizedBox(height: 80),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFF2563EB).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.notifications_active,
              color: Color(0xFF2563EB),
              size: 24,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Notification Center',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF111827),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_getFilteredNotifications().length} notifications • ${_notificationService.unreadCount} unread',
                  style: const TextStyle(
                    fontSize: 14,
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
      padding: const EdgeInsets.symmetric(horizontal: 16),
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
            const SizedBox(width: 8),
            _buildFilterChip(
              'Unread',
              _showOnlyUnread,
              () {
                setState(() {
                  _selectedFilter = null;
                  _showOnlyUnread = true;
                });
              },
            ),
            const SizedBox(width: 8),
            ...NotificationType.values.map((type) => Padding(
              padding: const EdgeInsets.only(right: 8),
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
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFF2563EB) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFF2563EB) 
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isSelected 
                ? Colors.white 
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationsList() {
    final notifications = _getFilteredNotifications();
    
    if (notifications.isEmpty) {
      return SliverFillRemaining(
        child: _buildEmptyState(),
      );
    }

    final groupedNotifications = _getGroupedFilteredNotifications();
    
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final entry = groupedNotifications.entries.elementAt(index);
          final dateKey = entry.key;
          final dayNotifications = entry.value;
          
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  dateKey,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ),
              
              // Notifications for this date
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: dayNotifications.map((notification) => 
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: NotificationCard(
                        notification: notification,
                        onTap: () => _handleNotificationTap(notification),
                        onMarkAsRead: () {
                          _notificationService.markAsRead(notification.id);
                          setState(() {});
                        },
                        onDelete: () {
                          _notificationService.deleteNotification(notification.id);
                          setState(() {});
                        },
                      ),
                    ),
                  ).toList(),
                ),
              ),
            ],
          );
        },
        childCount: groupedNotifications.length,
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.notifications_off_outlined,
              size: 40,
              color: Color(0xFF9CA3AF),
            ),
          ),
          
          const SizedBox(height: 16),
          
          const Text(
            'No notifications',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          
          const SizedBox(height: 8),
          
          Text(
            _selectedFilter != null 
                ? 'No ${_getTypeLabel(_selectedFilter!).toLowerCase()} notifications'
                : _showOnlyUnread 
                    ? 'No unread notifications'
                    : 'You\'re all caught up!',
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
            ),
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
      notifications = notifications
          .where((n) => !n.isRead)
          .toList();
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
        dateKey = '${notification.timestamp.day}/${notification.timestamp.month}/${notification.timestamp.year}';
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