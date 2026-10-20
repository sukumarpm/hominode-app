import 'dart:async';
import '../../events_announcements_screen.dart';
// lib/src/screens/notifications_screen.dart
// Notifications screen matching app design standards

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import '../models/notice_model.dart';
import '../services/notice_firestore_service.dart';
import '../services/announcements_events_service.dart';
import '../constants/app_sizes.dart';
import '../widgets/resident_visitor_page_background.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.loadNotifications,
    this.markRead,
    this.eventsService,
  });

  final Future<List<NoticeModel>> Function()? loadNotifications;
  final Future<void> Function(String)? markRead;
  final AnnouncementsEventsService? eventsService;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<NoticeModel> _allNotices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);

    try {
      print('========================================');
      print('🔵 NOTIFICATIONS SCREEN: Loading notifications');
      print('========================================');
      print('🔵 Calling NoticeFirestoreService.getNotices()...');

      // Keep the Firebase singleton lazy: an injected loader is used by
      // widget tests and must not initialize Firebase just to render the page.
      final notices = widget.loadNotifications != null
          ? await widget.loadNotifications!.call()
          : await NoticeFirestoreService.instance.getNotices();

      print('🔵 NoticeFirestoreService returned ${notices.length} notices');

      if (mounted) {
        setState(() {
          _allNotices = notices;
          _isLoading = false;
        });
        print('✅ UI updated with ${notices.length} notifications');
        print('========================================');
      }
    } catch (e, stackTrace) {
      print('❌ NOTIFICATIONS SCREEN ERROR: $e');
      print('   Stack trace: $stackTrace');
      print('========================================');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showNoticeDetail(NoticeModel notice) {
    if (widget.markRead != null) {
      unawaited(widget.markRead!(notice.id));
    } else if (widget.loadNotifications == null) {
      unawaited(NoticeFirestoreService.instance.markAsRead(notice.id));
    }
    if (notice.eventId != null) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => EventsAnnouncementsScreen(
            eventsOnly: true,
            eventId: notice.eventId,
            service: widget.eventsService,
          ),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(notice.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Category and Priority badges
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Category badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getIconBgColorForCategory(notice.category),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _getIconForCategory(notice.category),
                          size: 14.w,
                          color: _getIconColorForCategory(notice.category),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          _getCategoryLabel(notice.category),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: _getIconColorForCategory(notice.category),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Priority badge
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 10.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: _getPriorityBgColor(notice.priority),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      _getPriorityLabel(notice.priority),
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: _getPriorityTextColor(notice.priority),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 16.h),
              // Content
              Text(
                notice.content,
                style: TextStyle(fontSize: 15.sp, height: 1.5),
              ),
              SizedBox(height: 16.h),
              // Author
              if (notice.authorName.isNotEmpty) ...[
                Row(
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 16.w,
                      color: const Color(0xFF52627A),
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        'posted_by_name'.tr(
                          namedArgs: {'name': notice.authorName},
                        ),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF52627A),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
              ],
              // Published date
              Row(
                children: [
                  Icon(
                    Icons.calendar_today_outlined,
                    size: 16.w,
                    color: const Color(0xFF52627A),
                  ),
                  SizedBox(width: 6.w),
                  Flexible(
                    child: Text(
                      'published_date'.tr(
                        namedArgs: {
                          'date': _formatFullDate(notice.publishDate),
                        },
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF52627A),
                      ),
                    ),
                  ),
                ],
              ),
              // Expiry date
              if (notice.expiryDate != null) ...[
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.event_busy_outlined,
                      size: 16.w,
                      color: const Color(0xFF52627A),
                    ),
                    SizedBox(width: 6.w),
                    Flexible(
                      child: Text(
                        'expires_date'.tr(
                          namedArgs: {
                            'date': _formatFullDate(notice.expiryDate!),
                          },
                        ),
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: const Color(0xFF52627A),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              // Attachments
              if (notice.attachments.isNotEmpty) ...[
                SizedBox(height: 16.h),
                const Divider(),
                SizedBox(height: 8.h),
                Row(
                  children: [
                    Icon(
                      Icons.attach_file,
                      size: 16.w,
                      color: const Color(0xFF52627A),
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      'attachment_count'.tr(
                        namedArgs: {'count': '${notice.attachments.length}'},
                      ),
                      style: TextStyle(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF172B4D),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                ...notice.attachments.map(
                  (attachment) => Padding(
                    padding: EdgeInsets.only(bottom: 4.h),
                    child: Text(
                      '• $attachment',
                      style: TextStyle(
                        fontSize: 13.sp,
                        color: const Color(0xFF52627A),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.r),
        ),
        backgroundColor: const Color(0xFFFCFDFE),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('close'.tr()),
          ),
        ],
      ),
    );
  }

  String _formatFullDate(DateTime date) {
    return DateFormat.yMMMd(context.locale.toString()).add_Hm().format(date);
  }

  String _getCategoryLabel(String category) {
    final cat = category.toLowerCase();
    if (cat == 'maintenance') return 'maintenance'.tr();
    if (cat == 'event') return 'event'.tr();
    if (cat == 'emergency') return 'emergency'.tr();
    if (cat == 'urgent') return 'urgent'.tr();
    if (cat == 'billing') return 'billing'.tr();
    if (cat == 'security') return 'security'.tr();
    return category;
  }

  String _getPriorityLabel(String priority) {
    final p = priority.toLowerCase();
    if (p == 'urgent' || p == 'high') return 'urgent'.tr().toUpperCase();
    if (p == 'medium') return 'medium'.tr().toUpperCase();
    if (p == 'low') return 'low'.tr().toUpperCase();
    return priority.toUpperCase();
  }

  Color _getPriorityBgColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'urgent' || p == 'high') return const Color(0xFFFEE2E2);
    if (p == 'medium') return const Color(0xFFFEF3C7);
    if (p == 'low') return const Color(0xFFE0F2FE);
    return const Color(0xFFF3F4F6);
  }

  Color _getPriorityTextColor(String priority) {
    final p = priority.toLowerCase();
    if (p == 'urgent' || p == 'high') return const Color(0xFFDC2626);
    if (p == 'medium') return const Color(0xFFD97706);
    if (p == 'low') return const Color(0xFF0284C7);
    return const Color(0xFF6B7280);
  }

  IconData _getIconForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat == 'maintenance') return Icons.build_outlined;
    if (cat == 'event') return Icons.event_outlined;
    if (cat == 'emergency' || cat == 'urgent') {
      return Icons.warning_amber_outlined;
    }
    if (cat == 'billing') return Icons.receipt_outlined;
    if (cat == 'security') return Icons.security_outlined;
    return Icons.notifications_outlined;
  }

  Color _getIconBgColorForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat == 'maintenance') return const Color(0xFFFFF3E8);
    if (cat == 'event') return const Color(0xFFEDE9FF);
    if (cat == 'emergency' || cat == 'urgent') return const Color(0xFFFEE2E2);
    if (cat == 'billing') return const Color(0xFFE8FDEB);
    if (cat == 'security') return const Color(0xFFFEE2E2);
    return const Color(0xFFEAF1FF);
  }

  Color _getIconColorForCategory(String category) {
    final cat = category.toLowerCase();
    if (cat == 'maintenance') return const Color(0xFFF97316);
    if (cat == 'event') return const Color(0xFF8B5CF6);
    if (cat == 'emergency' || cat == 'urgent') return const Color(0xFFDC2626);
    if (cat == 'billing') return const Color(0xFF10B981);
    if (cat == 'security') return const Color(0xFFDC2626);
    return const Color(0xFF172B4D);
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'just_now'.tr();
        }
        return 'minutes_ago_short'.tr(
          namedArgs: {'count': '${difference.inMinutes}'},
        );
      }
      return 'hours_ago_short'.tr(
        namedArgs: {'count': '${difference.inHours}'},
      );
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr();
    } else if (difference.inDays < 7) {
      return 'days_ago_short'.tr(namedArgs: {'count': '${difference.inDays}'});
    } else {
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text('notifications'.tr()),
        backgroundColor: Colors.white.withValues(alpha: 0.82),
        foregroundColor: const Color(0xFF172B4D),
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: const Color(0xFF172B4D),
          fontSize: 20.sp,
          fontWeight: FontWeight.w700,
        ),
      ),
      body: ResidentVisitorPageBackground(
        child: Column(
          children: [
            // Notifications list
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _allNotices.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadNotifications,
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(
                          AppSizes.pagePadding,
                          0,
                          AppSizes.pagePadding,
                          AppSizes.pagePadding,
                        ),
                        itemCount: _allNotices.length,
                        itemBuilder: (context, index) {
                          final notice = _allNotices[index];

                          return Padding(
                            padding: EdgeInsets.only(bottom: 12.h),
                            child: _NoticeCard(
                              notice: notice,
                              onTap: () => _showNoticeDetail(notice),
                              formatDate: _formatDate,
                            ),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 64.w,
            color: const Color(0xFF52627A),
          ),
          SizedBox(height: 16.h),
          Text(
            'no_notifications'.tr(),
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF172B4D),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'you_are_all_caught_up'.tr(),
            style: TextStyle(fontSize: 14.sp, color: const Color(0xFF52627A)),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// NOTICE CARD - MATCHING APP DESIGN STANDARDS
// ============================================================================
class _NoticeCard extends StatelessWidget {
  final NoticeModel notice;
  final VoidCallback onTap;
  final String Function(DateTime) formatDate;

  const _NoticeCard({
    required this.notice,
    required this.onTap,
    required this.formatDate,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16.w),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(color: const Color(0xFFE2EAF3), width: 1),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF172B4D).withValues(alpha: 0.05),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon box
            Container(
              width: 48.w,
              height: 48.h,
              decoration: BoxDecoration(
                color: _getIconBgColor(notice.category),
                borderRadius: BorderRadius.circular(12.r),
              ),
              child: Icon(
                _getIcon(notice.category),
                size: 24.w,
                color: _getIconColor(notice.category),
              ),
            ),
            SizedBox(width: 12.w),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    notice.title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF172B4D),
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    notice.content,
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w400,
                      color: const Color(0xFF52627A),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 6.h),
                  Row(
                    children: [
                      // Priority badge
                      if (notice.priority == 'high' ||
                          notice.priority == 'urgent')
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 2.h,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(4.r),
                          ),
                          child: Text(
                            'urgent'.tr().toUpperCase(),
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFDC2626),
                            ),
                          ),
                        ),
                      if (notice.priority == 'high' ||
                          notice.priority == 'urgent')
                        SizedBox(width: 8.w),
                      // Category label
                      Text(
                        _getCategoryDisplayLabel(notice.category),
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: _getIconColor(notice.category),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        '•',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: const Color(0xFF52627A),
                        ),
                      ),
                      SizedBox(width: 4.w),
                      // Time
                      Expanded(
                        child: Text(
                          formatDate(notice.publishDate),
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w500,
                            color: const Color(0xFF52627A),
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Author name
                  if (notice.authorName.isNotEmpty) ...[
                    SizedBox(height: 4.h),
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 12.w,
                          color: const Color(0xFF52627A),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          notice.authorName,
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: const Color(0xFF52627A),
                          ),
                          softWrap: true,
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIcon(String category) {
    // Handle both 'category' and 'type' field names
    final cat = category.toLowerCase();

    if (cat == 'maintenance') {
      return Icons.build_outlined;
    } else if (cat == 'event') {
      return Icons.event_outlined;
    } else if (cat == 'emergency' || cat == 'urgent') {
      return Icons.warning_amber_outlined;
    } else if (cat == 'billing') {
      return Icons.receipt_outlined;
    } else if (cat == 'security') {
      return Icons.security_outlined;
    } else {
      // general or default
      return Icons.notifications_outlined;
    }
  }

  String _getCategoryDisplayLabel(String category) {
    final cat = category.toLowerCase();
    if (cat == 'maintenance') return 'maintenance'.tr();
    if (cat == 'event') return 'event'.tr();
    if (cat == 'emergency') return 'emergency'.tr();
    if (cat == 'urgent') return 'urgent'.tr();
    if (cat == 'billing') return 'billing'.tr();
    if (cat == 'security') return 'security'.tr();
    return 'general'.tr();
  }

  Color _getIconBgColor(String category) {
    final cat = category.toLowerCase();

    if (cat == 'maintenance') {
      return const Color(0xFFFFF3E8);
    } else if (cat == 'event') {
      return const Color(0xFFEDE9FF);
    } else if (cat == 'emergency' || cat == 'urgent') {
      return const Color(0xFFFEE2E2);
    } else if (cat == 'billing') {
      return const Color(0xFFE8FDEB);
    } else if (cat == 'security') {
      return const Color(0xFFFEE2E2);
    } else {
      // general or default
      return const Color(0xFFEAF1FF);
    }
  }

  Color _getIconColor(String category) {
    final cat = category.toLowerCase();

    if (cat == 'maintenance') {
      return const Color(0xFFF97316);
    } else if (cat == 'event') {
      return const Color(0xFF8B5CF6);
    } else if (cat == 'emergency' || cat == 'urgent') {
      return const Color(0xFFDC2626);
    } else if (cat == 'billing') {
      return const Color(0xFF10B981);
    } else if (cat == 'security') {
      return const Color(0xFFDC2626);
    } else {
      // general or default
      return const Color(0xFF172B4D);
    }
  }
}
