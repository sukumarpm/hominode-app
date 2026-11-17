import 'package:flutter_test/flutter_test.dart';
import 'package:resident_app/src/services/resident_dashboard_data_loader.dart';

void main() {
  test('pre-change dashboard secondary requests run serially', () async {
    final calls = <String>[];
    final firstRequestAt = DateTime.now();
    var lastRequestAt = firstRequestAt;

    Future<void> request(String name) async {
      calls.add(name);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      lastRequestAt = DateTime.now();
    }

    // This mirrors the existing order after the user profile read:
    // community document, bills, then visitors.
    await request('community');
    await request('bills');
    await request('visitors');

    expect(calls, ['community', 'bills', 'visitors']);
    // ignore: avoid_print
    print(
      'Resident dashboard baseline (synthetic): calls=${calls.length} '
      'serialSpanMs=${lastRequestAt.difference(firstRequestAt).inMilliseconds}',
    );
  });

  test(
    'post-change dashboard requests overlap and retain community scoping',
    () async {
      final calls = <String>[];
      var activeRequests = 0;
      var maxConcurrentRequests = 0;
      final timer = Stopwatch()..start();

      Future<T> request<T>(String name, T value) async {
        calls.add(name);
        activeRequests++;
        if (activeRequests > maxConcurrentRequests) {
          maxConcurrentRequests = activeRequests;
        }
        await Future<void>.delayed(const Duration(milliseconds: 20));
        activeRequests--;
        return value;
      }

      final result = await loadResidentDashboardSecondaryData(
        communityId: ' community-7 ',
        initialOrganizationName: 'Resident profile name',
        loadCommunityName: (communityId) {
          expect(communityId, 'community-7');
          return request('community', 'Community Seven');
        },
        loadBills: () => request('bills', [
          {'id': 'bill-1'},
        ]),
        loadVisitors: () => request('visitors', [
          {'id': 'visitor-1'},
        ]),
      );
      timer.stop();

      expect(calls, ['community', 'bills', 'visitors']);
      expect(calls.length, 3);
      expect(maxConcurrentRequests, 3);
      expect(result.organizationName, 'Community Seven');
      expect(result.bills.single['id'], 'bill-1');
      expect(result.visitors.single['id'], 'visitor-1');
      // ignore: avoid_print
      print(
        'Resident dashboard optimized (synthetic): calls=${calls.length} '
        'parallelSpanMs=${timer.elapsedMilliseconds} '
        'maxConcurrent=$maxConcurrentRequests',
      );
    },
  );

  test('community lookup failure keeps fallback name and other data', () async {
    final communityErrors = <Object>[];
    final result = await loadResidentDashboardSecondaryData(
      communityId: 'community-7',
      initialOrganizationName: 'Profile community',
      loadCommunityName: (_) async => throw StateError('unavailable'),
      loadBills: () async => [
        {'id': 'bill-1'},
      ],
      loadVisitors: () async => [
        {'id': 'visitor-1'},
      ],
      onCommunityLookupError: communityErrors.add,
    );

    expect(communityErrors, hasLength(1));
    expect(result.organizationName, 'Profile community');
    expect(result.bills, hasLength(1));
    expect(result.visitors, hasLength(1));
  });

  test(
    'bill and visitor failures still propagate to the dashboard handler',
    () async {
      var visitorLoadStarted = false;
      final loading = loadResidentDashboardSecondaryData(
        communityId: null,
        initialOrganizationName: 'Profile community',
        loadCommunityName: (_) async => fail('No community lookup expected'),
        loadBills: () async => throw StateError('bills unavailable'),
        loadVisitors: () async {
          visitorLoadStarted = true;
          return [];
        },
      );

      await expectLater(loading, throwsA(isA<StateError>()));
      expect(visitorLoadStarted, isTrue);
    },
  );
}
