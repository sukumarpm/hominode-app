import 'package:flutter/material.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
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
  State<EventsAnnouncementsScreen> createState() => _EventsAnnouncementsScreenState();
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
      return Scaffold(
        backgroundColor: const Color(0xFFF7F8FA),
        body: const Center(
          child: CircularProgressIndicator(),
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
                const SizedBox(height: 20),
                
                // Section Header
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Manage community activities',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Tab Switcher
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: SegmentedControlExamples.eventsSegmentedControl(
                    selectedIndex: selectedTab,
                    onChanged: (index) {
                      setState(() {
                        selectedTab = index;
                      });
                    },
                  ),
                ),
                
                const SizedBox(height: 20),
                
                // Create Button (Dynamic based on selected tab)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: PrimaryButton(
                    text: selectedTab == 0 ? 'Create Event' : 'Create Announcements',
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
                        final result = await showCreateAnnouncementModal(context);
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
                                  content: Text('Announcement created successfully'),
                                  backgroundColor: Color(0xFF10B981),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create announcement: $e'),
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
                
                const SizedBox(height: 20),
                
                // Event Cards List
                selectedTab == 0 ? _buildEventsList() : _buildAnnouncementsList(),
                
                const SizedBox(height: 80), // Bottom padding for navigation
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsList() {
    return StreamBuilder<List<EventModel>>(
      stream: _service.getEvents(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                  const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_outlined, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No events yet',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first event to get started',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: events.map((event) => Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 16.0),
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
                    content: Text('Are you sure you want to delete "${event.title}"? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
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
          )).toList(),
        );
      },
    );
  }

  Widget _buildAnnouncementsList() {
    return StreamBuilder<List<AnnouncementModel>>(
      stream: _service.getAnnouncements(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(32.0),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError) {
          return Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Color(0xFFEF4444)),
                  const SizedBox(height: 16),
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
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.campaign_outlined, size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text(
                    'No announcements yet',
                    style: TextStyle(fontSize: 15, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create your first announcement to get started',
                    style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          );
        }

        return Column(
          children: announcements.map((announcement) => Padding(
            padding: const EdgeInsets.only(left: 20.0, right: 20.0, bottom: 16.0),
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
                            content: Text('Announcement updated successfully'),
                            backgroundColor: Color(0xFF10B981),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update announcement: $e'),
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
                    content: Text('Are you sure you want to delete "${announcement.title}"? This action cannot be undone.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: TextButton.styleFrom(foregroundColor: const Color(0xFFEF4444)),
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
                          content: Text('Announcement deleted successfully'),
                          backgroundColor: Color(0xFF10B981),
                        ),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Failed to delete announcement: $e'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  }
                }
              },
            ),
          )).toList(),
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
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 16),
            ],
            
            // Top Row - Title and Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Row(
                  children: [
                    const StatusBadge(text: 'Upcoming'),
                    if (onDelete != null) ...[
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: onDelete,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFEF4444),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 12),
            
            // Category Tag
            CategoryTag(text: event.category),
            
            const SizedBox(height: 12),
            
            // Description
            Text(
              event.description,
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Event Details Row
            Row(
              children: [
                _buildDetailItem(Icons.calendar_today_outlined, event.date),
                const SizedBox(width: 16),
                _buildDetailItem(Icons.access_time_outlined, event.time),
              ],
            ),
            
            const SizedBox(height: 8),
            
            _buildDetailItem(Icons.location_on_outlined, event.location),
            
            const SizedBox(height: 16),
            
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
        Icon(
          icon,
          size: 16,
          color: const Color(0xFF6B7280),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: const TextStyle(
            fontSize: 14,
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
        height: 160,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(
          Icons.image_not_supported,
          color: Color(0xFF9CA3AF),
          size: 48,
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: double.infinity,
        height: 160,
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
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildTab('Events', 0),
          ),
          Expanded(
            child: _buildTab('Announcements', 1),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(String text, int index) {
    final isSelected = selectedIndex == index;
    
    return GestureDetector(
      onTap: () => onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
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
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? const Color(0xFF111827) : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const PrimaryButton({
    super.key,
    required this.text,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2563EB),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String text;

  const StatusBadge({
    super.key,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFE0EBFF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Color(0xFF2563EB),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isAnnouncement ? const Color(0xFFF3F4F6) : Colors.transparent,
        border: isAnnouncement ? null : Border.all(color: const Color(0xFF2563EB)),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isAnnouncement ? const Color(0xFF111827) : const Color(0xFF2563EB),
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
            const Icon(
              Icons.people_outline,
              size: 16,
              color: Color(0xFF6B7280),
            ),
            const SizedBox(width: 6),
            Text(
              '$rsvpCount / $totalCapacity RSVP',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            color: const Color(0xFFE5E7EB),
            borderRadius: BorderRadius.circular(3),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB),
                borderRadius: BorderRadius.circular(3),
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
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PriorityBadge(priority: announcement.priority),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Second Row - Category and Date
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CategoryTag(text: announcement.category, isAnnouncement: true),
              Text(
                announcement.date,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Text(
            announcement.description,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF6B7280),
              height: 1.4,
            ),
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 16),
          
          // Action Buttons Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onSendReminder,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Send Reminder',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onEdit,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black,
                    side: const BorderSide(color: Color(0xFFD1D5DB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Edit',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              if (onDelete != null) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: onDelete,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEE2E2),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFEF4444).withOpacity(0.2)),
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      size: 20,
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

  const PriorityBadge({
    super.key,
    required this.priority,
  });

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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        priority,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: textColor,
        ),
      ),
    );
  }
}