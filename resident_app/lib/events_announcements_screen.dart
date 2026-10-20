// lib/events_announcements_screen.dart
// Events & Announcements Screen with Firestore integration

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:easy_localization/easy_localization.dart';
import 'src/components/app_segmented_control.dart';
import 'src/models/announcement_model.dart';
import 'src/models/event_model.dart';
import 'src/services/announcements_events_service.dart';
import 'src/widgets/resident_visitor_page_background.dart';

// Design Constants
const kPrimaryBlue = Color(0xFF172B4D);
const kSectionTitle = Color(0xFF172B4D);
const kSubtitle = Color(0xFF52627A);
const kCardBackground = Color(0xFFFFFFFF);
const kDivider = Color(0xFFE6E6E6);
const kCardRadius = 20.0;
const kSpacing = 16.0;

// Priority colors
const kHighPriorityBg = Color(0xFFFEE2E2);
const kHighPriorityText = Color(0xFFEF4444);
const kMediumPriorityBg = Color(0xFFDBEAFE);
const kMediumPriorityText = Color(0xFF0E4778);
const kLowPriorityBg = Color(0xFFD1FAE5);
const kLowPriorityText = Color(0xFF10B981);

class EventsAnnouncementsScreen extends StatefulWidget {
  const EventsAnnouncementsScreen({
    super.key,
    this.eventsOnly = false,
    this.announcementsOnly = false,
    this.service,
    this.eventId,
  });

  final bool eventsOnly;
  final bool announcementsOnly;
  final AnnouncementsEventsService? service;
  final String? eventId;

  @override
  State<EventsAnnouncementsScreen> createState() =>
      _EventsAnnouncementsScreenState();
}

class _EventsAnnouncementsScreenState extends State<EventsAnnouncementsScreen> {
  int _selectedTab = 0; // 0: Announcements, 1: Events
  late final AnnouncementsEventsService _service;
  Future<EventModel?>? _eventDetails;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AnnouncementsEventsService();
    if (widget.eventsOnly) _selectedTab = 1;
    if (widget.eventId != null) _eventDetails = _loadEventDetails();
  }

  Future<void> _selectTab(int index) async {
    if (index == 1) {
      final communityId = await _service.currentCommunityId();
      if (!mounted) return;
      if (communityId == null || !await _service.eventsAllowed(communityId)) {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text('events_unavailable_title'.tr()),
            content: Text('events_restricted'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text('ok'.tr()),
              ),
            ],
          ),
        );
        return;
      }
    }
    if (mounted) setState(() => _selectedTab = index);
  }

  @override
  Widget build(BuildContext context) {
    final showAnnouncementsTitle =
        widget.eventId == null &&
        (widget.announcementsOnly || (!widget.eventsOnly && _selectedTab == 0));
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: .82),
        foregroundColor: kSectionTitle,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          showAnnouncementsTitle ? 'announcements'.tr() : 'events'.tr(),
          style: TextStyle(
            color: kSectionTitle,
            fontSize: 20.sp,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ResidentVisitorPageBackground(
        child: Column(
          children: [
            SizedBox(height: 14.h),

            // Segmented Control
            if (widget.eventId == null &&
                !widget.eventsOnly &&
                !widget.announcementsOnly)
              AppSegmentedControl(
                segments: ['announcements'.tr(), 'events'.tr()],
                selectedIndex: _selectedTab,
                onChanged: (index) {
                  _selectTab(index);
                },
              ),

            SizedBox(height: 14.h),

            // Content
            Expanded(
              child: widget.eventId != null
                  ? _buildEventDetails()
                  : widget.eventsOnly
                  ? _buildEventsTab()
                  : widget.announcementsOnly
                  ? _buildAnnouncementsTab()
                  : _selectedTab == 0
                  ? _buildAnnouncementsTab()
                  : _buildEventsTab(),
            ),
          ],
        ),
      ),
    );
  }

  /// Announcements Tab
  Widget _buildAnnouncementsTab() {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: _service.streamAnnouncements(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56.w,
                  color: const Color(0xFF9AABC0),
                ),
                SizedBox(height: 16.h),
                Text(
                  'error_loading_announcements'.tr(),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: kSectionTitle,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'please_try_again_later'.tr(),
                  style: TextStyle(fontSize: 14.sp, color: kSubtitle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final announcements = snapshot.data ?? [];

        // Empty state
        if (announcements.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.campaign_outlined,
                  size: 64.w,
                  color: const Color(0xFF9AABC0),
                ),
                SizedBox(height: 16.h),
                Text(
                  'no_announcements'.tr(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: kSectionTitle,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'check_back_announcements'.tr(),
                  style: TextStyle(fontSize: 14.sp, color: kSubtitle),
                ),
              ],
            ),
          );
        }

        // List of announcements
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
          itemCount: announcements.length,
          itemBuilder: (context, index) {
            return _buildAnnouncementCard(announcements[index]);
          },
        );
      },
    );
  }

  /// Events Tab
  Widget _buildEventsTab() {
    return StreamBuilder<List<EventModel>>(
      stream: _service.streamEvents(),
      builder: (context, snapshot) {
        // Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(kPrimaryBlue),
            ),
          );
        }

        // Error state
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.error_outline,
                  size: 56.w,
                  color: const Color(0xFF9AABC0),
                ),
                SizedBox(height: 16.h),
                Text(
                  'error_loading_events'.tr(),
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.w600,
                    color: kSectionTitle,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'please_try_again_later'.tr(),
                  style: TextStyle(fontSize: 14.sp, color: kSubtitle),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        final events = snapshot.data ?? [];

        // Empty state
        if (events.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_outlined,
                  size: 56.w,
                  color: const Color(0xFF9AABC0),
                ),
                SizedBox(height: 16.h),
                Text(
                  'no_events'.tr(),
                  style: TextStyle(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.w600,
                    color: kSectionTitle,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  'check_back_events'.tr(),
                  style: TextStyle(fontSize: 14.sp, color: kSubtitle),
                ),
              ],
            ),
          );
        }

        // List of events
        return ListView.builder(
          padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 20.h),
          itemCount: events.length,
          itemBuilder: (context, index) {
            return _buildEventCard(events[index]);
          },
        );
      },
    );
  }

  /// Announcement Card
  Widget _buildAnnouncementCard(AnnouncementModel announcement) {
    return Container(
      margin: EdgeInsets.only(bottom: 16.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: const Color(0xFFE5EAF0)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF172B4D).withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(18.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (announcement.attachments.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12.r),
                child: Image.network(
                  announcement.attachments.first,
                  width: double.infinity,
                  height: 170.h,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            if (announcement.attachments.isNotEmpty) SizedBox(height: 12.h),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8.w,
              runSpacing: 8.h,
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 5.h,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEEF2F6),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Text(
                    _localizedCategory(announcement.category),
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryBlue,
                    ),
                  ),
                ),
                SizedBox(width: 8.w),
                _buildPriorityBadge(announcement.priority),
                Icon(Icons.campaign_outlined, size: 20.w, color: kPrimaryBlue),
              ],
            ),
            SizedBox(height: 14.h),
            Text(
              announcement.title,
              style: TextStyle(
                fontSize: 17.sp,
                fontWeight: FontWeight.w700,
                color: kSectionTitle,
                height: 1.25,
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              announcement.description,
              style: TextStyle(fontSize: 14.sp, color: kSubtitle, height: 1.5),
              softWrap: true,
            ),
            SizedBox(height: 14.h),
            const Divider(height: 1, color: Color(0xFFEEF1F5)),
            SizedBox(height: 12.h),
            Row(
              children: [
                Icon(Icons.schedule_outlined, size: 15.w, color: kSubtitle),
                SizedBox(width: 5.w),
                Text(
                  _formatDate(announcement.createdAt),
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: kSubtitle,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<EventModel?> _loadEventDetails() async {
    try {
      return await _service
          .getEvent(widget.eventId!)
          .timeout(const Duration(seconds: 25));
    } catch (error) {
      debugPrint('Event details unavailable (${error.runtimeType}).');
      return null;
    }
  }

  Widget _buildEventDetails() => FutureBuilder<EventModel?>(
    future: _eventDetails,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      if (snapshot.hasError || snapshot.data == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('error_loading_events'.tr(), textAlign: TextAlign.center),
                TextButton(
                  onPressed: () => setState(() {
                    _eventDetails = _loadEventDetails();
                  }),
                  child: Text('retry'.tr()),
                ),
              ],
            ),
          ),
        );
      }
      return SingleChildScrollView(
        padding: EdgeInsets.all(18.w),
        child: _buildEventCard(snapshot.data!, interactive: false),
      );
    },
  );

  void _openEvent(String id) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EventsAnnouncementsScreen(
          eventsOnly: true,
          eventId: id,
          service: _service,
        ),
      ),
    );
  }

  /// Event Card
  Widget _buildEventCard(EventModel event, {bool interactive = true}) {
    final card = Container(
      margin: EdgeInsets.only(bottom: 18.h),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .96),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: const Color(0xFFE3E9F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 22,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (event.imageUrls.isNotEmpty)
            _buildEventImageHeader(event.imageUrls),

          Padding(
            padding: EdgeInsets.all(18.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.w,
                  runSpacing: 8.h,
                  children: [
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10.w,
                        vertical: 5.h,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEEF2F6),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _localizedCategory(event.category),
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryBlue,
                        ),
                      ),
                    ),
                    SizedBox(width: 8.w),
                    _buildStatusBadge(event.status),
                  ],
                ),

                SizedBox(height: 14.h),

                Text(
                  event.title,
                  style: TextStyle(
                    fontSize: 19.sp,
                    fontWeight: FontWeight.w800,
                    color: kSectionTitle,
                    height: 1.2,
                  ),
                ),

                if (event.description.isNotEmpty) ...[
                  SizedBox(height: 8.h),
                  Text(
                    event.description,
                    style: TextStyle(
                      fontSize: 14.sp,
                      color: kSubtitle,
                      height: 1.5,
                    ),
                    softWrap: true,
                  ),
                ],

                SizedBox(height: 16.h),

                Wrap(
                  spacing: 14.w,
                  runSpacing: 10.h,
                  children: [
                    if (event.eventDate != null)
                      _eventMeta(
                        Icons.calendar_month_outlined,
                        _formatEventDate(event.eventDate!),
                      ),
                    if (event.location != null &&
                        event.location!.trim().isNotEmpty)
                      _eventMeta(Icons.location_on_outlined, event.location!),
                    if (event.totalCapacity != null && event.totalCapacity! > 0)
                      _eventMeta(
                        Icons.groups_outlined,
                        'event_capacity'.tr(
                          namedArgs: {'count': '${event.totalCapacity}'},
                        ),
                      ),
                  ],
                ),

                SizedBox(height: 14.h),
                const Divider(height: 1, color: Color(0xFFEEF1F5)),
                SizedBox(height: 12.h),

                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8.w,
                  runSpacing: 4.h,
                  children: [
                    Icon(Icons.schedule_outlined, size: 15.w, color: kSubtitle),
                    SizedBox(width: 5.w),
                    Text(
                      'posted_date'.tr(
                        namedArgs: {'date': _formatDate(event.createdAt)},
                      ),
                      style: TextStyle(fontSize: 12.sp, color: kSubtitle),
                    ),
                    if (event.imageUrls.length > 1)
                      TextButton.icon(
                        onPressed: () => _showEventGallery(event.imageUrls),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: Text(
                          'photo_count'.tr(
                            namedArgs: {'count': '${event.imageUrls.length}'},
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
    );
    return interactive
        ? Semantics(
            button: true,
            label: event.title,
            child: GestureDetector(
              onTap: () => _openEvent(event.id),
              child: card,
            ),
          )
        : card;
  }

  Widget _eventMeta(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17.w, color: kPrimaryBlue),
        SizedBox(width: 5.w),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 240.w),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12.5.sp,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEventImageHeader(List<String> images) {
    return GestureDetector(
      onTap: () => _showEventGallery(images),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(
              images.first,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFFEAF1F8),
                alignment: Alignment.center,
                child: Icon(
                  Icons.image_not_supported_outlined,
                  size: 42.w,
                  color: Colors.grey[500],
                ),
              ),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.20),
                    ],
                  ),
                ),
              ),
            ),
            if (images.length > 1)
              Positioned(
                right: 12.w,
                bottom: 12.h,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 10.w,
                    vertical: 6.h,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.65),
                    borderRadius: BorderRadius.circular(20.r),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.photo_library_outlined,
                        size: 15.w,
                        color: Colors.white,
                      ),
                      SizedBox(width: 5.w),
                      Text(
                        '${images.length}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  void _showEventGallery(List<String> images) {
    if (images.isEmpty) return;

    showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (dialogContext) {
        return Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: SafeArea(
            child: Stack(
              children: [
                PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (_, index) {
                    return InteractiveViewer(
                      child: Center(
                        child: Image.network(
                          images[index],
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.white54,
                            size: 64,
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    onPressed: () => Navigator.of(dialogContext).pop(),
                    icon: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _localizedCategory(String category) {
    final key = switch (category.toLowerCase()) {
      'maintenance' => 'maintenance',
      'event' => 'event',
      'emergency' => 'emergency',
      'urgent' => 'urgent',
      'billing' => 'billing',
      'security' => 'security',
      'general' => 'general',
      _ => null,
    };
    return key == null ? category : key.tr();
  }

  /// Priority Badge
  Widget _buildPriorityBadge(String priority) {
    Color bgColor;
    Color textColor;
    String label;

    switch (priority.toLowerCase()) {
      case 'high':
        bgColor = kHighPriorityBg;
        textColor = kHighPriorityText;
        label = 'high'.tr();
        break;
      case 'low':
        bgColor = kLowPriorityBg;
        textColor = kLowPriorityText;
        label = 'low'.tr();
        break;
      default:
        bgColor = kMediumPriorityBg;
        textColor = kMediumPriorityText;
        label = 'medium'.tr();
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// Status Badge for Events
  Widget _buildStatusBadge(String status) {
    Color bgColor;
    Color textColor;
    String label;

    switch (status.toLowerCase()) {
      case 'upcoming':
        bgColor = kMediumPriorityBg;
        textColor = kMediumPriorityText;
        label = 'upcoming'.tr();
        break;
      case 'active':
      case 'ongoing':
        bgColor = kLowPriorityBg;
        textColor = kLowPriorityText;
        label = 'active'.tr();
        break;
      case 'completed':
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = 'completed'.tr();
        break;
      case 'cancelled':
        bgColor = kHighPriorityBg;
        textColor = kHighPriorityText;
        label = 'cancelled'.tr();
        break;
      default:
        bgColor = Colors.grey[200]!;
        textColor = Colors.grey[700]!;
        label = status;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6.r),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11.sp,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }

  /// Format date
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'today'.tr();
    } else if (difference.inDays == 1) {
      return 'yesterday'.tr();
    } else if (difference.inDays < 7) {
      return 'days_ago'.tr(namedArgs: {'count': '${difference.inDays}'});
    } else {
      return DateFormat('MMM d, yyyy', context.locale.toString()).format(date);
    }
  }

  /// Format event date
  String _formatEventDate(DateTime date) {
    return DateFormat(
      'MMM d, yyyy • h:mm a',
      context.locale.toString(),
    ).format(date);
  }
}
