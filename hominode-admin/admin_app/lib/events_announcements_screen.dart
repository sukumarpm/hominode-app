import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'desktop/admin_desktop_page_frame.dart';
import 'widgets/create_event_modal.dart';
import 'widgets/edit_announcement_modal.dart';
import 'widgets/create_announcement_modal.dart';
import 'widgets/standard_header.dart';
import 'widgets/admin_content_status.dart';
import 'widgets/custom_segmented_control.dart';
import 'services/event_announcement_service.dart';
import 'services/admin_service.dart';
import 'services/subscription_service.dart';

class EventsAnnouncementsScreen extends StatefulWidget {
  const EventsAnnouncementsScreen({
    super.key,
    this.eventsOnly = false,
    this.announcementsOnly = false,
    this.service,
    this.adminService,
    this.subscriptionService,
  });

  final EventAnnouncementService? service;
  final AdminService? adminService;
  final SubscriptionService? subscriptionService;
  final bool eventsOnly;
  final bool announcementsOnly;

  @override
  State<EventsAnnouncementsScreen> createState() =>
      _EventsAnnouncementsScreenState();
}

class _EventsAnnouncementsScreenState extends State<EventsAnnouncementsScreen> {
  int selectedTab = 0; // 0 = Events, 1 = Announcements
  late final EventAnnouncementService _service =
      widget.service ?? EventAnnouncementService();
  late final AdminService _adminService = widget.adminService ?? AdminService();
  late final SubscriptionService _subscriptionService =
      widget.subscriptionService ?? SubscriptionService();

  bool _isInitialized = false;
  bool _eventsAllowed = false;
  String? _initializationError;
  bool _entitlementFailed = false;
  Stream<List<EventModel>>? _eventsStream;
  Stream<List<AnnouncementModel>>? _announcementsStream;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    setState(() {
      _isInitialized = false;
      _initializationError = null;
      _eventsAllowed = false;
      _entitlementFailed = false;
    });
    try {
      if (_adminService.getCurrentAdminId() == null) {
        throw StateError('User not authenticated');
      }
      final adminProfile = await _adminService.getAdminProfile().timeout(
        const Duration(seconds: 20),
      );
      if (adminProfile == null) throw StateError('Admin profile not found');

      var eventsAllowed = false;
      var entitlementFailed = false;
      try {
        final communityId = _adminService.requireCurrentCommunityId();
        final entitlement = await _subscriptionService
            .getEntitlement(communityId)
            .timeout(const Duration(seconds: 20));
        eventsAllowed = entitlement?.canUseFeature('events') == true;
      } catch (error) {
        entitlementFailed = true;
        debugPrint('Events entitlement resolution failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _eventsAllowed = eventsAllowed;
        _entitlementFailed = entitlementFailed;
        // Announcements remain available to Essential communities.
        if (!_eventsAllowed) selectedTab = 1;
        if (widget.eventsOnly) selectedTab = 0;
        if (widget.announcementsOnly) selectedTab = 1;
        _isInitialized = true;
      });
    } catch (error) {
      debugPrint('Events initialization failed: $error');
      if (!mounted) return;
      setState(
        () => _initializationError = 'Unable to load community communications.',
      );
    }
  }

  Future<void> _selectTab(int index) async {
    if (!_isInitialized) return;
    if (index == 0 && !_eventsAllowed) {
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Events unavailable'),
          content: const Text(
            'Events are available with Hominode Plus and Pro.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    if (!mounted) return;

    setState(() {
      selectedTab = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: widget.announcementsOnly ? 'Announcements' : 'Events',
        subtitle: 'Create and manage community communications.',
        actions: !_isInitialized || (widget.eventsOnly && !_eventsAllowed)
            ? []
            : [
                AdminDesktopPrimaryAction(
                  label: selectedTab == 0
                      ? 'Create Event'
                      : 'Create Announcement',
                  icon: selectedTab == 0
                      ? Icons.event_available_outlined
                      : Icons.campaign_outlined,
                  onPressed: _createSelectedItem,
                ),
              ],
        child: Column(
          children: [
            if (!widget.eventsOnly && !widget.announcementsOnly)
              SegmentedControlExamples.eventsSegmentedControl(
                selectedIndex: selectedTab,
                onChanged: (index) {
                  _selectTab(index);
                },
              ),
            SizedBox(height: 16.h),
            Expanded(child: SingleChildScrollView(child: _buildContent())),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          StandardHeader(
            title: widget.announcementsOnly ? 'Announcements' : 'Events',
          ),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),

                // Section Header
                if (!widget.eventsOnly && !widget.announcementsOnly)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                    child: Text(
                      'Manage community activities',
                      style: TextStyle(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                  ),

                SizedBox(height: 20.h),

                // Tab Switcher
                if (!widget.eventsOnly && !widget.announcementsOnly)
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                    child: SegmentedControlExamples.eventsSegmentedControl(
                      selectedIndex: selectedTab,
                      onChanged: (index) {
                        _selectTab(index);
                      },
                    ),
                  ),

                SizedBox(height: 20.h),

                // Create Button (Dynamic based on selected tab)
                if (_isInitialized && (!widget.eventsOnly || _eventsAllowed))
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                    child: PrimaryButton(
                      text:
                          widget.eventsOnly ||
                              (!widget.announcementsOnly && selectedTab == 0)
                          ? 'Create Event'
                          : 'Create Announcements',
                      onPressed: _createSelectedItem,
                    ),
                  ),

                SizedBox(height: 20.h),

                // Event Cards List
                _buildContent(),

                SizedBox(height: 80.h), // Bottom padding for navigation
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_initializationError != null) {
      return AdminContentStatus(
        message: _initializationError!,
        onRetry: _initializeScreen,
      );
    }
    if (!_isInitialized) {
      return const AdminContentStatus(
        message: 'Loading community communications…',
      );
    }
    final showEvents =
        widget.eventsOnly || (!widget.announcementsOnly && selectedTab == 0);
    if (showEvents) {
      if (_entitlementFailed) {
        return AdminContentStatus(
          message: 'Unable to verify Events access.',
          onRetry: _initializeScreen,
        );
      }
      return _eventsAllowed ? _buildEventsList() : _buildEventsUnavailable();
    }
    return _buildAnnouncementsList();
  }

  Future<void> _createSelectedItem() async {
    if (!_isInitialized) return;
    try {
      if (selectedTab == 0 && !_eventsAllowed) {
        await _selectTab(0);
        return;
      }

      if (selectedTab == 0) {
        String? eventId;
        final result = await showCreateEventModal(
          context,
          onSubmit: (data) async {
            eventId ??= _service.newEventId();
            await _service.createEvent(
              eventId: eventId,
              title: data['title'],
              category: data['category'] ?? 'General',
              description: data['description'] ?? '',
              date: data['date'] ?? DateTime.now(),
              time: data['time'] ?? '6:00 PM',
              location: data['location'] ?? 'Community Hall',
              imageFile: data['imageFile'],
            );
          },
        );
        if (result == null) {
          if (eventId != null) {
            try {
              await _service.discardEventAttempt(eventId!);
            } catch (_) {
              // Do not log file paths, download URLs or profile details.
              debugPrint(
                'Event photo cleanup was not confirmed; no referenced image was removed.',
              );
            }
          }
          return;
        }
        if (!mounted) return;
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Event created successfully'),
              backgroundColor: Color(0xFF10B981),
            ),
          );
        }
        return;
      }

      final result = await showCreateAnnouncementModal(context);
      if (result == null || !context.mounted) return;
      await _service.createAnnouncement(
        title: result['title'],
        category: result['category'] ?? 'General',
        priority: result['priority'] ?? 'medium',
        description: result['message'] ?? '',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Announcement created successfully'),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to create item: $error'),
          backgroundColor: const Color(0xFFEF4444),
        ),
      );
    }
  }

  Widget _buildEventsUnavailable() => Padding(
    padding: EdgeInsets.all(32.w),
    child: const Center(
      child: Text('Events are available with Hominode Plus and Pro.'),
    ),
  );

  Stream<List<EventModel>> _watchEvents() async* {
    yield* _service.getEvents();
  }

  Stream<List<AnnouncementModel>> _watchAnnouncements() async* {
    yield* _service.getAnnouncements();
  }

  Widget _buildEventsList() {
    return StreamBuilder<List<EventModel>>(
      stream: _eventsStream ??= _watchEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(32.0.w),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return AdminContentStatus(
            message: 'Unable to load events.',
            onRetry: () => setState(() => _eventsStream = null),
          );
        }

        final events = snapshot.data ?? [];

        if (events.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(32.w),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.event_outlined,
                    size: 56.w,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No events yet',
                    style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Create your first event to get started',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: events
              .map(
                (event) => Padding(
                  padding: EdgeInsets.only(
                    left: 20.0.w,
                    right: 20.0.w,
                    bottom: 16.0.h,
                  ),
                  child: EventCardWidget(
                    event: EventData(
                      title: event.title,
                      category: event.category,
                      description: event.description,
                      date: event.formattedDate,
                      time: event.time,
                      location: event.location,
                      rsvpCount: event.rsvpCount,
                      totalCapacity: event.totalCapacity,
                      imagePath: event.imageUrl,
                    ),
                    onTap: () {
                      // TODO: Navigate to event detail screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Tapped on ${event.title}')),
                      );
                    },
                    onDelete: () async {
                      // Show confirmation dialog
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Event'),
                          content: Text(
                            'Are you sure you want to delete "${event.title}"? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFFEF4444),
                              ),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirmed == true) {
                        try {
                          await _service.deleteEvent(event.id);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Event deleted successfully'),
                                backgroundColor: Color(0xFF10B981),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Failed to delete event: $e'),
                                backgroundColor: Color(0xFFEF4444),
                              ),
                            );
                          }
                        }
                      }
                    },
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildAnnouncementsList() {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: _announcementsStream ??= _watchAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(32.0.w),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return AdminContentStatus(
            message: 'Unable to load announcements.',
            onRetry: () => setState(() => _announcementsStream = null),
          );
        }

        final announcements = snapshot.data ?? [];

        if (announcements.isEmpty) {
          return Padding(
            padding: EdgeInsets.all(32.w),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.campaign_outlined,
                    size: 56.w,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 12.h),
                  Text(
                    'No announcements yet',
                    style: TextStyle(fontSize: 15.sp, color: Colors.grey[600]),
                  ),
                  SizedBox(height: 8.h),
                  Text(
                    'Create your first announcement to get started',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: announcements
              .map(
                (announcement) => Padding(
                  padding: EdgeInsets.only(
                    left: 20.0.w,
                    right: 20.0.w,
                    bottom: 16.0.h,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (announcement.attachments.isNotEmpty)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            announcement.attachments.first,
                            height: 180,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) =>
                                const SizedBox.shrink(),
                          ),
                        ),
                      AnnouncementCardWidget(
                        announcement: AnnouncementData(
                          title: announcement.title,
                          category: announcement.category,
                          priority: announcement.priority,
                          description: announcement.description,
                          date: announcement.formattedDate,
                        ),
                        onSendReminder: () async {
                          try {
                            await _service.sendReminder(
                              announcement.id,
                              sourceCollection: announcement.sourceCollection,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Reminder sent successfully'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to send reminder: $e'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        },
                        onEdit: () {
                          showEditAnnouncementModal(
                            context,
                            AnnouncementData(
                              title: announcement.title,
                              category: announcement.category,
                              priority: announcement.priority,
                              description: announcement.description,
                              date: announcement.formattedDate,
                            ),
                            (updatedAnnouncement) async {
                              try {
                                await _service.updateAnnouncement(
                                  announcementId: announcement.id,
                                  title: updatedAnnouncement.title,
                                  category: updatedAnnouncement.category,
                                  priority: updatedAnnouncement.priority,
                                  description: updatedAnnouncement.description,
                                  sourceCollection:
                                      announcement.sourceCollection,
                                );

                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Announcement updated successfully',
                                      ),
                                      backgroundColor: Color(0xFF10B981),
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Failed to update announcement: $e',
                                      ),
                                      backgroundColor: Color(0xFFEF4444),
                                    ),
                                  );
                                }
                              }
                            },
                          );
                        },
                        onDelete: () async {
                          // Show confirmation dialog
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Delete Announcement'),
                              content: Text(
                                'Are you sure you want to delete "${announcement.title}"? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: TextButton.styleFrom(
                                    foregroundColor: const Color(0xFFEF4444),
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          );

                          if (confirmed == true) {
                            try {
                              await _service.deleteAnnouncement(
                                announcement.id,
                                sourceCollection: announcement.sourceCollection,
                              );
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Announcement deleted successfully',
                                    ),
                                    backgroundColor: Color(0xFF10B981),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to delete announcement: $e',
                                    ),
                                    backgroundColor: Color(0xFFEF4444),
                                  ),
                                );
                              }
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

class EventData {
  final String title;
  final String category;
  final String description;
  final String date;
  final String time;
  final String location;
  final int rsvpCount;
  final int totalCapacity;
  final String? imagePath; // Optional image URL for network images
  final String?
  localImagePath; // Legacy argument; never rendered as shared media.

  EventData({
    required this.title,
    required this.category,
    required this.description,
    required this.date,
    required this.time,
    required this.location,
    required this.rsvpCount,
    required this.totalCapacity,
    this.imagePath,
    this.localImagePath,
  });

  // Helper to check if event has any image
  bool get hasImage => imagePath != null;
}

class AnnouncementData {
  final String title;
  final String category;
  final String priority;
  final String description;
  final String date;

  AnnouncementData({
    required this.title,
    required this.category,
    required this.priority,
    required this.description,
    required this.date,
  });
}

class EventCardWidget extends StatelessWidget {
  final EventData event;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const EventCardWidget({
    super.key,
    required this.event,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(20.0.w),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12.r),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Event Image (if available)
            if (event.hasImage) ...[
              _buildEventImage(event),
              SizedBox(height: 16.h),
            ],

            // Top Row - Title and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Row(
                  children: [
                    const StatusBadge(text: 'Upcoming'),
                    if (onDelete != null) ...[
                      SizedBox(width: 8.w),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: EdgeInsets.all(6.w),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: Icon(
                            Icons.delete_outline,
                            size: 18.w,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),

            SizedBox(height: 12.h),

            // Category Tag
            CategoryTag(text: event.category),

            SizedBox(height: 12.h),

            // Description
            Text(
              event.description,
              style: TextStyle(
                fontSize: 14.sp,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),

            SizedBox(height: 16.h),

            // Event Details Row
            Row(
              children: [
                _buildDetailItem(Icons.calendar_today_outlined, event.date),
                SizedBox(width: 16.w),
                _buildDetailItem(Icons.access_time_outlined, event.time),
              ],
            ),

            SizedBox(height: 8.h),

            _buildDetailItem(Icons.location_on_outlined, event.location),

            SizedBox(height: 16.h),

            // RSVP Section
            RsvpProgressBar(
              rsvpCount: event.rsvpCount,
              totalCapacity: event.totalCapacity,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 16.w, color: const Color(0xFF6B7280)),
        SizedBox(width: 6.w),
        Text(
          text,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: Color(0xFF111827),
          ),
        ),
      ],
    );
  }

  Widget _buildEventImage(EventData event) {
    Widget imageWidget;

    if (event.imagePath != null) {
      // Display network image
      imageWidget = Image.network(
        event.imagePath!,
        errorBuilder: (_, _, _) =>
            const Center(child: Icon(Icons.image_not_supported_outlined)),
        width: double.infinity,
        height: 160,
        fit: BoxFit.cover,
      );
    } else {
      // Fallback (shouldn't happen if hasImage is used correctly)
      imageWidget = Container(
        width: double.infinity,
        height: 160.h,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Icon(
          Icons.image_not_supported,
          color: Color(0xFF9CA3AF),
          size: 48.w,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8.r),
      child: SizedBox(
        width: double.infinity,
        height: 160.h,
        child: imageWidget,
      ),
    );
  }
}

class SegmentedTabSwitcher extends StatelessWidget {
  final int selectedIndex;
  final Function(int) onTabChanged;

  const SegmentedTabSwitcher({
    super.key,
    required this.selectedIndex,
    required this.onTabChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Row(
        children: [
          Expanded(child: _buildTab('Events', 0)),
          Expanded(child: _buildTab('Announcements', 1)),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = selectedIndex == index;

    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12.h),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8.r),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
            color: isSelected
                ? const Color(0xFF111827)
                : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({super.key, required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0E4778),
          foregroundColor: Colors.white,
          padding: EdgeInsets.symmetric(vertical: 16.h),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: TextStyle(fontSize: 16.sp, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;

  const StatusBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: const Color(0xFFE0EBFF),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: Color(0xFF0E4778),
        ),
      ),
    );
  }
}

class CategoryTag extends StatelessWidget {
  final String text;
  final bool isAnnouncement;

  const CategoryTag({
    super.key,
    required this.text,
    this.isAnnouncement = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
      decoration: BoxDecoration(
        color: isAnnouncement ? const Color(0xFFF3F4F6) : Colors.transparent,
        border: isAnnouncement
            ? null
            : Border.all(color: const Color(0xFF0E4778)),
        borderRadius: BorderRadius.circular(16.r),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: isAnnouncement
              ? const Color(0xFF111827)
              : const Color(0xFF0E4778),
        ),
      ),
    );
  }
}

class RsvpProgressBar extends StatelessWidget {
  final int rsvpCount;
  final int totalCapacity;

  const RsvpProgressBar({
    super.key,
    required this.rsvpCount,
    required this.totalCapacity,
  });

  @override
  Widget build(BuildContext context) {
    final progress = rsvpCount / totalCapacity;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.people_outline, size: 16.w, color: Color(0xFF6B7280)),
            SizedBox(width: 6.w),
            Text(
              '$rsvpCount / $totalCapacity RSVP',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Container(
          height: 6.h,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(3.r),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF0E4778),
                borderRadius: BorderRadius.circular(3.r),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AnnouncementCardWidget extends StatelessWidget {
  final AnnouncementData announcement;
  final VoidCallback onSendReminder;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;

  const AnnouncementCardWidget({
    super.key,
    required this.announcement,
    required this.onSendReminder,
    required this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.0.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row - Title and Priority Badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  announcement.title,
                  style: TextStyle(
                    fontSize: 16.sp,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              PriorityBadge(priority: announcement.priority),
            ],
          ),

          SizedBox(height: 12.h),

          // Second Row - Category and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CategoryTag(text: announcement.category, isAnnouncement: true),
              Text(
                announcement.date,
                style: TextStyle(fontSize: 13.sp, color: Color(0xFF6B7280)),
              ),
            ],
          ),

          SizedBox(height: 12.h),

          // Description
          Text(
            announcement.description,
            style: TextStyle(
              fontSize: 14.sp,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
            softWrap: true,
          ),

          SizedBox(height: 16.h),

          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSendReminder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Send Reminder',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                SizedBox(width: 12.w),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: EdgeInsets.all(12.w),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(
                        color: const Color(0xFFEF4444).withOpacity(0.2),
                      ),
                    ),
                    child: Icon(
                      Icons.delete_outline,
                      size: 20.w,
                      color: Color(0xFFEF4444),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class PriorityBadge extends StatelessWidget {
  final String priority;

  const PriorityBadge({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor = Colors.white;

    switch (priority.toLowerCase()) {
      case 'high':
        backgroundColor = const Color(0xFFEF4444);
        break;
      case 'medium':
        backgroundColor = const Color(0xFFF59E0B);
        break;
      case 'low':
        backgroundColor = const Color(0xFF22C55E);
        break;
      default:
        backgroundColor = const Color(0xFF6B7280);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12.r),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 12.sp,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}
