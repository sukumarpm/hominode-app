import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'widgets/standard_header.dart';
import 'models/notice_models.dart';
import 'services/notice_service.dart';
import 'widgets/create_notice_modal.dart';
import 'widgets/notice_detail_modal.dart';

class NoticesManagementScreen extends StatefulWidget {
  const NoticesManagementScreen({super.key});

  @override
  State<NoticesManagementScreen> createState() =>
      _NoticesManagementScreenState();
}

class _NoticesManagementScreenState extends State<NoticesManagementScreen> {
  String searchQuery = '';
  NoticeStatus selectedStatus = NoticeStatus.published;
  NoticeType? selectedType;
  final NoticeService _noticeService = NoticeService();

  List<Notice> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  void _loadNotices() {
    print('NoticesManagementScreen: Loading notices from Firestore');
    _noticeService.getNotices().listen(
      (noticeModels) async {
        print(
          'NoticesManagementScreen: Received ${noticeModels.length} notices',
        );

        List<Notice> notices = noticeModels
            .map((model) => _convertToNotice(model))
            .toList();

        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      },
      onError: (error) {
        print('NoticesManagementScreen ERROR: $error');
        setState(() {
          _isLoading = false;
        });
      },
    );
  }

  Notice _convertToNotice(NoticeModel model) {
    return Notice(
      id: model.id,
      title: model.title,
      content: model.content,
      type: _getNoticeTypeFromString(model.type),
      priority: _getNoticePriorityFromString(model.priority),
      status: _getNoticeStatusFromString(model.status),
      createdAt: model.createdAt ?? DateTime.now(),
      publishedAt: model.publishedAt,
      expiresAt: model.expiresAt,
      authorId: model.authorId,
      authorName: model.authorName,
      targetBuildings: [], // Not used anymore, using targetFlats
      targetFloors: [],
      isUrgent: model.isUrgent,
      requiresAcknowledgment: model.requiresAcknowledgment,
      viewCount: model.viewCount,
      acknowledgmentCount: model.acknowledgmentCount,
      attachments: model.attachments,
    );
  }

  NoticeType _getNoticeTypeFromString(String type) {
    switch (type.toLowerCase()) {
      case 'general':
        return NoticeType.general;
      case 'maintenance':
        return NoticeType.maintenance;
      case 'emergency':
        return NoticeType.emergency;
      case 'event':
        return NoticeType.event;
      case 'billing':
        return NoticeType.billing;
      case 'security':
        return NoticeType.security;
      default:
        return NoticeType.general;
    }
  }

  NoticePriority _getNoticePriorityFromString(String priority) {
    switch (priority.toLowerCase()) {
      case 'low':
        return NoticePriority.low;
      case 'medium':
        return NoticePriority.medium;
      case 'high':
        return NoticePriority.high;
      case 'urgent':
        return NoticePriority.urgent;
      default:
        return NoticePriority.medium;
    }
  }

  NoticeStatus _getNoticeStatusFromString(String status) {
    switch (status.toLowerCase()) {
      case 'draft':
        return NoticeStatus.draft;
      case 'published':
        return NoticeStatus.published;
      case 'archived':
        return NoticeStatus.archived;
      default:
        return NoticeStatus.draft;
    }
  }

  List<Notice> get filteredNotices {
    return _notices.where((notice) {
      final matchesSearch =
          searchQuery.isEmpty ||
          notice.title.toLowerCase().contains(searchQuery.toLowerCase()) ||
          notice.content.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesStatus = notice.status == selectedStatus;

      final matchesType = selectedType == null || notice.type == selectedType;

      return matchesSearch && matchesStatus && matchesType;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F7F7),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
              ),
            )
          : CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const StandardHeader(title: 'Notices Management'),
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _buildHeaderSection(),
                      _buildSearchAndFilters(),
                      _buildStatusTabs(),
                      _buildTypeFilters(),
                    ],
                  ),
                ),
                SliverPadding(
                  padding: EdgeInsets.all(16.w),
                  sliver: filteredNotices.isEmpty
                      ? SliverToBoxAdapter(child: _buildEmptyState())
                      : SliverList(
                          delegate: SliverChildBuilderDelegate((
                            context,
                            index,
                          ) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: 12.h),
                              child: NoticeCard(
                                notice: filteredNotices[index],
                                onTap: () =>
                                    _showNoticeDetail(filteredNotices[index]),
                                onEdit: () =>
                                    _editNotice(filteredNotices[index]),
                                onDelete: () =>
                                    _deleteNotice(filteredNotices[index]),
                                onPublish: () =>
                                    _publishNotice(filteredNotices[index]),
                              ),
                            );
                          }, childCount: filteredNotices.length),
                        ),
                ),
                SliverToBoxAdapter(child: SizedBox(height: 80.h)),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createNewNotice,
        backgroundColor: const Color(0xFF0E4778),
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text(
          'Create Notice',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10B981), Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Icon(
              Icons.notifications_active,
              color: Colors.white,
              size: 28.w,
            ),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notice Board',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  '${_notices.where((n) => n.status == NoticeStatus.published).length} Active Notices',
                  style: TextStyle(
                    fontSize: 14.sp,
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
          _buildStatCard('Total', _notices.length.toString()),
          SizedBox(width: 8.w),
          _buildStatCard(
            'Drafts',
            _notices
                .where((n) => n.status == NoticeStatus.draft)
                .length
                .toString(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          Text(
            label,
            style: TextStyle(
              fontSize: 11.sp,
              color: Colors.white.withOpacity(0.9),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          onChanged: (value) => setState(() => searchQuery = value),
          decoration: InputDecoration(
            hintText: 'Search notices...',
            hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
            prefixIcon: Icon(Icons.search, color: Color(0xFF6B7280)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(vertical: 16.h),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusTabs() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          _buildStatusTab('Published', NoticeStatus.published),
          _buildStatusTab('Drafts', NoticeStatus.draft),
          _buildStatusTab('Archived', NoticeStatus.archived),
        ],
      ),
    );
  }

  Widget _buildStatusTab(String label, NoticeStatus status) {
    final isSelected = selectedStatus == status;
    final count = _notices.where((n) => n.status == status).length;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedStatus = status),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  color: isSelected
                      ? const Color(0xFF111827)
                      : const Color(0xFF6B7280),
                ),
              ),
              SizedBox(width: 6.w),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF10B981)
                      : const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 11.sp,
                    fontWeight: FontWeight.w600,
                    color: isSelected ? Colors.white : const Color(0xFF6B7280),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypeFilters() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Row(
        children: [
          _buildTypeChip('All', null),
          SizedBox(width: 8.w),
          ...NoticeType.values.map(
            (type) => Padding(
              padding: EdgeInsets.only(right: 8.w),
              child: _buildTypeChip(type.displayName, type),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String label, NoticeType? type) {
    final isSelected = selectedType == type;

    return GestureDetector(
      onTap: () => setState(() => selectedType = type),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
        decoration: BoxDecoration(
          color: isSelected
              ? (type?.color ?? const Color(0xFF0E4778))
              : Colors.white,
          borderRadius: BorderRadius.circular(20.r),
          border: Border.all(
            color: isSelected
                ? (type?.color ?? const Color(0xFF0E4778))
                : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (type != null) ...[
              Icon(
                type.icon,
                size: 16.w,
                color: isSelected ? Colors.white : type.color,
              ),
              SizedBox(width: 6.w),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 13.sp,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : const Color(0xFF374151),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      margin: EdgeInsets.all(16.w),
      padding: EdgeInsets.all(40.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(20.w),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 48.w,
              color: Color(0xFF9CA3AF),
            ),
          ),
          SizedBox(height: 16.h),
          Text(
            'No Notices Found',
            style: TextStyle(
              fontSize: 18.sp,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            searchQuery.isEmpty
                ? 'Create your first notice to get started'
                : 'Try adjusting your search or filters',
            style: TextStyle(fontSize: 14.sp, color: Color(0xFF6B7280)),
          ),
        ],
      ),
    );
  }

  void _createNewNotice() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateNoticeModal(),
    );
  }

  void _showNoticeDetail(Notice notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => NoticeDetailModal(notice: notice),
    );
  }

  void _editNotice(Notice notice) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateNoticeModal(notice: notice),
    );
  }

  void _deleteNotice(Notice notice) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Notice'),
        content: Text('Are you sure you want to delete "${notice.title}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await _noticeService.deleteNotice(notice.id);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notice deleted successfully'),
                      backgroundColor: Color(0xFF10B981),
                    ),
                  );
                }
              } catch (e) {
                print(
                  'NoticesManagementScreen ERROR: Failed to delete notice: $e',
                );
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to delete notice: $e'),
                      backgroundColor: const Color(0xFFEF4444),
                    ),
                  );
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _publishNotice(Notice notice) async {
    try {
      await _noticeService.publishNotice(notice.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Notice "${notice.title}" published successfully'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      print('NoticesManagementScreen ERROR: Failed to publish notice: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to publish notice: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }
}

class NoticeCard extends StatelessWidget {
  final Notice notice;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onPublish;

  const NoticeCard({
    super.key,
    required this.notice,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    required this.onPublish,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(
            color: notice.isUrgent
                ? const Color(0xFFEF4444).withOpacity(0.3)
                : const Color(0xFFE5E7EB),
            width: notice.isUrgent ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.all(16.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8.w),
                        decoration: BoxDecoration(
                          color: notice.type.backgroundColor,
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Icon(
                          notice.type.icon,
                          color: notice.type.color,
                          size: 20.w,
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    notice.title,
                                    style: TextStyle(
                                      fontSize: 16.sp,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF111827),
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (notice.isUrgent)
                                  Container(
                                    margin: EdgeInsets.only(left: 8.w),
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8.w,
                                      vertical: 4.h,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEF4444),
                                      borderRadius: BorderRadius.circular(4.r),
                                    ),
                                    child: Text(
                                      'URGENT',
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(height: 4.h),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: notice.type.backgroundColor,
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    notice.type.displayName,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: notice.type.color,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8.w),
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 8.w,
                                    vertical: 2.h,
                                  ),
                                  decoration: BoxDecoration(
                                    color: notice.priority.color.withOpacity(
                                      0.1,
                                    ),
                                    borderRadius: BorderRadius.circular(4.r),
                                  ),
                                  child: Text(
                                    notice.priority.displayName,
                                    style: TextStyle(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w600,
                                      color: notice.priority.color,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    notice.content,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: Color(0xFF6B7280),
                      height: 1.5,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 12.h),
                  Row(
                    children: [
                      Icon(
                        Icons.person_outline,
                        size: 14.w,
                        color: const Color(0xFF9CA3AF),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        notice.authorName,
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      SizedBox(width: 12.w),
                      Icon(
                        Icons.access_time,
                        size: 14.w,
                        color: const Color(0xFF9CA3AF),
                      ),
                      SizedBox(width: 4.w),
                      Text(
                        _formatDate(notice.createdAt),
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      if (notice.status == NoticeStatus.published) ...[
                        const Spacer(),
                        Icon(
                          Icons.visibility_outlined,
                          size: 14.w,
                          color: const Color(0xFF9CA3AF),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          '${notice.viewCount}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(16.r),
                  bottomRight: Radius.circular(16.r),
                ),
              ),
              child: Row(
                children: [
                  if (notice.requiresAcknowledgment &&
                      notice.status == NoticeStatus.published) ...[
                    Icon(
                      Icons.check_circle_outline,
                      size: 16.w,
                      color: const Color(0xFF10B981),
                    ),
                    SizedBox(width: 4.w),
                    Text(
                      '${notice.acknowledgmentCount}/${notice.viewCount} acknowledged',
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF10B981),
                      ),
                    ),
                    const Spacer(),
                  ] else
                    const Spacer(),
                  if (notice.status == NoticeStatus.draft)
                    TextButton.icon(
                      onPressed: onPublish,
                      icon: Icon(Icons.publish, size: 16.w),
                      label: const Text('Publish'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF10B981),
                        padding: EdgeInsets.symmetric(
                          horizontal: 12.w,
                          vertical: 6.h,
                        ),
                      ),
                    ),
                  TextButton.icon(
                    onPressed: onEdit,
                    icon: Icon(Icons.edit_outlined, size: 16.w),
                    label: const Text('Edit'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF0E4778),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_outline, size: 16.w),
                    label: const Text('Delete'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                      padding: EdgeInsets.symmetric(
                        horizontal: 12.w,
                        vertical: 6.h,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'Today';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    } else {
      return DateFormat('dd MMM yyyy').format(date);
    }
  }
}
