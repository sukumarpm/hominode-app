import 'dart:async';

import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/community_settings_screen.dart';
import 'package:admin_app/services/community_invite_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _Service extends Fake implements CommunityInviteService {
  int writes = 0;
  bool fail = false;
  Completer<TenantConfig>? pending;
  final community = _community();

  @override
  Future<TenantConfig> updateCommunityLocation(
    TenantConfig community,
    CommunityLocation location,
  ) {
    writes++;
    if (fail) return Future.error(StateError('permission denied'));
    return pending?.future ?? Future.value(_community(location: location));
  }
}

const _location = CommunityLocation(
  latitude: 14.6,
  longitude: 121.0,
  formattedAddress: 'Green Valley',
  attendanceRadiusMeters: 150,
);

TenantConfig _community({CommunityLocation? location}) => TenantConfig(
  communityId: 'GV-0701',
  name: 'Green Valley',
  slug: 'green-valley',
  websitePath: '/green-valley',
  databaseId: '(default)',
  isActive: true,
  createdBy: 'admin',
  locationConfigured: location != null,
  location: location,
);

Future<void> _open(WidgetTester tester, _Service service) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => showDialog<TenantConfig>(
              context: context,
              barrierDismissible: true,
              builder: (_) => CommunityAttendanceLocationDialog(
                service: service,
                community: _community(),
                pickerBuilder: (context, onChanged) => TextButton(
                  onPressed: () => onChanged(_location),
                  child: const Text('Set test location'),
                ),
              ),
            ),
            child: const Text('Open location dialog'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open location dialog'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Cancel closes without saving', (tester) async {
    final service = _Service();
    await _open(tester, service);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttendanceLocationDialog), findsNothing);
    expect(service.writes, 0);
  });

  testWidgets('Save shows validation feedback when no location is selected', (
    tester,
  ) async {
    final service = _Service();
    await _open(tester, service);
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(find.textContaining('Choose a map location'), findsOneWidget);
    expect(service.writes, 0);
  });

  testWidgets('Save returns success and duplicate taps write once', (
    tester,
  ) async {
    final service = _Service()..pending = Completer<TenantConfig>();
    await _open(tester, service);
    await tester.tap(find.text('Set test location'));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tap(find.byType(FilledButton));
    expect(service.writes, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.pending!.complete(_community(location: _location));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttendanceLocationDialog), findsNothing);
  });

  testWidgets('save failure is visible and leaves the dialog available', (
    tester,
  ) async {
    final service = _Service()..fail = true;
    await _open(tester, service);
    await tester.tap(find.text('Set test location'));
    await tester.tap(find.byType(FilledButton));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('location-dialog-error')), findsOneWidget);
    expect(
      find.textContaining('Could not save the attendance location'),
      findsOneWidget,
    );
    expect(find.byType(CommunityAttendanceLocationDialog), findsOneWidget);
  });

  testWidgets('outside tap dismisses the idle dialog', (tester) async {
    final service = _Service();
    await _open(tester, service);
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    expect(find.byType(CommunityAttendanceLocationDialog), findsNothing);
    expect(service.writes, 0);
  });

  testWidgets('outside tap cannot dismiss while saving', (tester) async {
    final service = _Service()..pending = Completer<TenantConfig>();
    await _open(tester, service);
    await tester.tap(find.text('Set test location'));
    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    await tester.tapAt(const Offset(5, 5));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(CommunityAttendanceLocationDialog), findsOneWidget);
    expect(service.writes, 1);
    service.pending!.complete(_community(location: _location));
    await tester.pumpAndSettle();
  });
}
