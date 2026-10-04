import 'package:admin_app/services/reports_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

ReportsService _service({String Function()? communityProvider}) {
  return ReportsService(
    firestore: FakeFirebaseFirestore(),
    currentAdminIdProvider: () => 'admin-1',
    currentCommunityIdProvider: communityProvider ?? () => 'community-1',
  );
}

void main() {
  group('ReportsService occupancy and complaints', () {
    test('an empty community is a valid zero occupancy report', () async {
      final service = _service();

      final summary = await service.getOccupancySummary();
      final buildings = await service.getBuildingOccupancy();

      expect(summary.totalFlats, 0);
      expect(summary.occupiedFlats, 0);
      expect(summary.vacantFlats, 0);
      expect(summary.maintenanceFlats, 0);
      expect(summary.occupancyRate, 0);
      expect(buildings, isEmpty);
    });

    test('occupancy query failures become safe service errors', () async {
      final service = _service(
        communityProvider: () => throw StateError('private query details'),
      );

      await expectLater(
        service.getOccupancySummary(),
        throwsA(
          isA<ReportsServiceException>().having(
            (error) => error.userMessage,
            'safe message',
            'Occupancy report is unavailable right now. Please try again shortly.',
          ),
        ),
      );
      await expectLater(
        service.getBuildingOccupancy(),
        throwsA(
          isA<ReportsServiceException>().having(
            (error) => error.userMessage,
            'safe message',
            'Building occupancy is unavailable right now. Please try again shortly.',
          ),
        ),
      );
    });

    test('an empty deliveries month is a valid zero count', () async {
      final service = _service();

      final count = await service.getDeliveriesCount(year: 2030, month: 1);

      expect(count, 0);
    });

    test('delivery query failures throw a safe service error', () async {
      final service = _service(
        communityProvider: () => throw StateError('private query details'),
      );

      await expectLater(
        service.getDeliveriesCount(year: 2030, month: 1),
        throwsA(
          isA<ReportsServiceException>()
              .having(
                (error) => error.userMessage,
                'safe message',
                'Deliveries are unavailable right now. Please try again shortly.',
              )
              .having(
                (error) => error.technicalMessage,
                'technical message',
                contains('private query details'),
              ),
        ),
      );
    });

    test('an empty month is a valid zero complaints report', () async {
      final service = _service();

      final summary = await service.getComplaintsSummary(year: 2030, month: 1);
      final trends = await service.getMonthlyComplaintsTrends();

      expect(summary.totalComplaints, 0);
      expect(summary.resolvedComplaints, 0);
      expect(summary.pendingComplaints, 0);
      expect(summary.inProgressComplaints, 0);
      expect(summary.resolutionRate, 0);
      expect(summary.categoryBreakdown, isEmpty);
      expect(trends, hasLength(6));
      expect(trends.every((trend) => trend.totalComplaints == 0), isTrue);
    });

    test(
      'complaints query and trend failures become safe service errors',
      () async {
        final service = _service(
          communityProvider: () => throw StateError('private query details'),
        );

        await expectLater(
          service.getComplaintsSummary(year: 2030, month: 1),
          throwsA(
            isA<ReportsServiceException>().having(
              (error) => error.userMessage,
              'safe message',
              'Complaints report is unavailable right now. Please try again shortly.',
            ),
          ),
        );
        await expectLater(
          service.getMonthlyComplaintsTrends(),
          throwsA(
            isA<ReportsServiceException>().having(
              (error) => error.userMessage,
              'safe message',
              'Complaint trends are unavailable right now. Please try again shortly.',
            ),
          ),
        );
      },
    );
  });
}
