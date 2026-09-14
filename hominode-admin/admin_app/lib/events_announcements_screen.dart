import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'desktop/admin_desktop_page_frame.dart';
import 'widgets/create_event_modal.dart';
import 'widgets/edit_announcement_modal.dart';
import 'widgets/create_announcement_modal.dart';
import 'widgets/standard_header.dart';
import 'widgets/custom_segmented_control.dart';
import 'services/event_announcement_service.dart';
import 'services/admin_service.dart';

class EventsAnnouncementsScreen extends StatefulWidget {
  const EventsAnnouncementsScreen({super.key});

  @override
  State<EventsAnnouncementsScreen> createState() =>
      _EventsAnnouncementsScreenState();
}

class _EventsAnnouncementsScreenState extends State<EventsAnnouncementsScreen> {
  int selectedTab = 0; // 0 = Events, 1 = Announcements
  final EventAnnouncementService _service = EventAnnouncementService();
  final AdminService _adminService = AdminService();
  bool _isInitialized = false;
  String? _adminId;

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      print('🔵 EVENTS SCREEN: Starting initialization...');

      // STEP 1: Validate Admin Authentication
      print('🔐 STEP 1: Validating admin authentication...');
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        throw Exception('User not authenticated');
      }
      _adminId = user.uid;
      print('✅ STEP 1 PASSED: Admin authenticated - $_adminId');

      // STEP 2: Validate Admin Access
      print('📋 STEP 2: Validating admin access...');
      final adminProfile = await _adminService.getAdminProfile();
      if (adminProfile == null) {
        throw Exception('Admin profile not found');
      }
      print('✅ STEP 2 PASSED: Admin access validated');

      // STEP 3: Initialize Data Streams
      print('🔄 STEP 3: Initializing data streams...');
      // Streams are initialized in build method via StreamBuilder
      print('✅ STEP 3 PASSED: Data streams ready');

      // STEP 4: Update UI State
      print('🔔 STEP 4: Updating UI state...');
      if (mounted) {
        setState(() {
          _isInitialized = true;
        });
      }
      print('✅ STEP 4 PASSED: UI state updated');
      print('✅ EVENTS SCREEN: Initialization COMPLETE');
    } catch (e) {
      print('❌ ERROR: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error initializing events: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      if (AdminDesktopPresentationScope.isActive(context)) {
        return const Center(child: CircularProgressIndicator());
      }
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (AdminDesktopPresentationScope.isActive(context)) {
      return AdminDesktopPageFrame(
        title: 'Events & Announcements',
        subtitle: 'Create and manage community communications.',
        actions: [
          AdminDesktopPrimaryAction(
            label: selectedTab == 0 ? 'Create Event' : 'Create Announcement',
            icon: selectedTab == 0
                ? Icons.event_available_outlined
                : Icons.campaign_outlined,
            onPressed: _createSelectedItem,
          ),
        ],
        child: Column(
          children: [
            SegmentedControlExamples.eventsSegmentedControl(
              selectedIndex: selectedTab,
              onChanged: (index) => setState(() => selectedTab = index),
            ),
            SizedBox(height: 16.h),
            Expanded(
              child: SingleChildScrollView(
                child: selectedTab == 0
                    ? _buildEventsList()
                    : _buildAnnouncementsList(),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          const StandardHeader(title: 'Events & Announcements'),
          SliverToBoxAdapter(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(height: 20.h),

                // Section Header
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
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                  child: SegmentedControlExamples.eventsSegmentedControl(
                    selectedIndex: selectedTab,
                    onChanged: (index) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                  ),
                ),

                SizedBox(height: 20.h),

                // Create Button (Dynamic based on selected tab)
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0.w),
                  child: PrimaryButton(
                    text: selectedTab == 0
                        ? 'Create Event'
                        : 'Create Announcements',
                    onPressed: () async {
                      if (selectedTab == 0) {
                        final result = await showCreateEventModal(context);
                        if (result != null && mounted) {
                          try {
                            await _service.createEvent(
                              title: result['title'],
                              category: result['category'] ?? 'General',
                              description: result['description'] ?? '',
                              date: result['date'] ?? DateTime.now(),
                              time: result['time'] ?? '6:00 PM',
                              location: result['location'] ?? 'Community Hall',
                              imageUrl: result['imageUrl'],
                              localImagePath: result['localImagePath'],
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Event created successfully'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create event: $e'),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        }
                      } else {
                        final result = await showCreateAnnouncementModal(
                          context,
                        );
                        if (result != null && mounted) {
                          try {
                            await _service.createAnnouncement(
                              title: result['title'],
                              category: result['category'] ?? 'General',
                              priority: result['priority'] ?? 'medium',
                              description: result['message'] ?? '',
                            );

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Announcement created successfully',
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
                                    'Failed to create announcement: $e',
                                  ),
                                  backgroundColor: Color(0xFFEF4444),
                                ),
                              );
                            }
                          }
                        }
                      }
                    },
                  ),
                ),

                SizedBox(height: 20.h),

                // Event Cards List
                selectedTab == 0
                    ? _buildEventsList()
                    : _buildAnnouncementsList(),

                SizedBox(height: 80.h), // Bottom padding for navigation
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _createSelectedItem() async {
    try {
      if (selectedTab == 0) {
        final result = await showCreateEventModal(context);
        if (result == null || !context.mounted) return;
        await _service.createEvent(
          title: result['title'],
          category: result['category'] ?? 'General',
          description: result['description'] ?? '',
          date: result['date'] ?? DateTime.now(),
          time: result['time'] ?? '6:00 PM',
          location: result['location'] ?? 'Community Hall',
          imageUrl: result['imageUrl'],
          localImagePath: result['localImagePath'],
        );
        if (context.mounted) {
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

  Widget _buildEventsList() {
    return StreamBuilder<List<EventModel>>(
      stream: _service.getEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(32.0.w),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.all(32.0.w),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading events: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
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
                      localImagePath: event.localImagePath,
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
      stream: _service.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Padding(
            padding: EdgeInsets.all(32.0.w),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: EdgeInsets.all(32.0.w),
            child: Center(
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48.w,
                    color: Color(0xFFEF4444),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    'Error loading announcements: ${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Color(0xFF6B7280)),
                  ),
                ],
              ),
            ),
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
                  child: AnnouncementCardWidget(
                    announcement: AnnouncementData(
                      title: announcement.title,
                      category: announcement.category,
                      priority: announcement.priority,
                      description: announcement.description,
                      date: announcement.formattedDate,
                    ),
                    onSendReminder: () async {
                      try {
                        await _service.sendReminder(announcement.id);
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
                          await _service.deleteAnnouncement(announcement.id);
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
  final String? localImagePath; // Optional local file path

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
  bool get hasImage => imagePath != null || localImagePath != null;
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

    if (event.localImagePath != null) {
      // Display local file image
      imageWidget = Image.file(
        File(event.localImagePath!),
        width: double.infinity,
        height: 160,
        fit: BoxFit.cover,
      );
    } else if (event.imagePath != null) {
      // Display network image
      imageWidget = Image.network(
        event.imagePath!,
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
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
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
