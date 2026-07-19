// lib/src/services/notices_repository.dart
// Repository for notices data with API stubs

import '../models/notice.dart';

/// API Contract:
/// GET /notices -> List of all notices

class NoticesRepository {
  static final NoticesRepository _instance = NoticesRepository._internal();
  factory NoticesRepository() => _instance;
  NoticesRepository._internal();

  /// Fetch all notices
  /// API: GET /notices
  Future<List<Notice>> fetchNotices() async {
    await Future.delayed(const Duration(milliseconds: 500));
    return _getMockNotices();
  }

  List<Notice> _getMockNotices() {
    return [
      Notice(
        id: 'ntc_1',
        title: 'Water Supply Maintenance',
        excerpt: 'Water supply will be interrupted on Nov 3rd from 10 AM to 2 PM for maintenance work.',
        fullContent: '''Water supply will be interrupted on November 3rd from 10:00 AM to 2:00 PM for essential maintenance work.

Please store sufficient water in advance. We apologize for any inconvenience caused.

For emergencies, contact the maintenance team at ext. 234.''',
        date: DateTime(2025, 10, 30),
        priority: NoticePriority.high,
      ),
      Notice(
        id: 'ntc_2',
        title: 'Parking Rules Update',
        excerpt: 'New parking guidelines have been implemented. Please check the notice board for details.',
        fullContent: '''New parking guidelines have been implemented effective immediately:

1. Visitor parking is now available in Zone C
2. Resident parking stickers must be displayed
3. No parking in fire lanes (strictly enforced)

Please check the notice board in the lobby for complete details and parking map.''',
        date: DateTime(2025, 10, 28),
        priority: NoticePriority.medium,
      ),
      Notice(
        id: 'ntc_3',
        title: 'Community Meeting',
        excerpt: 'Monthly community meeting scheduled for Nov 10th at 7 PM in the clubhouse.',
        fullContent: '''Monthly community meeting is scheduled for November 10th at 7:00 PM in the clubhouse.

Agenda:
- Budget review
- Upcoming maintenance projects
- Community events planning
- Q&A session

All residents are encouraged to attend.''',
        date: DateTime(2025, 11, 5),
        priority: NoticePriority.medium,
      ),
    ];
  }
}
