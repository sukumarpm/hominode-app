import 'package:admin_app/models/tenant_config.dart';
import 'package:admin_app/services/community_location_service.dart';
import 'package:admin_app/widgets/community_location_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class FakeLocationGateway implements CommunityLocationGateway {
  int searchCalls = 0;

  @override
  String? lastSearchSessionToken;
  String? lastResolveSessionToken;

  @override
  Future<List<CommunityLocationSuggestion>> search(
    String query, {
    required String sessionToken,
    String? countryCode,
  }) async {
    searchCalls++;
    lastSearchSessionToken = sessionToken;
    return const [
      CommunityLocationSuggestion(
        placeId: 'place-green-valley',
        primaryText: 'Green Valley',
        secondaryText: 'Manila, Philippines',
        displayText: 'Green Valley, Manila, Philippines',
      ),
    ];
  }

  @override
  Future<CommunityLocationSearchResult> resolvePlace(
    String placeId, {
    required String sessionToken,
  }) async {
    lastResolveSessionToken = sessionToken;
    return const CommunityLocationSearchResult(
      latitude: 14.5995,
      longitude: 120.9842,
      formattedAddress: 'Green Valley, Manila',
      placeId: 'place-green-valley',
    );
  }

  @override
  Future<Position> getCurrentPosition() async => Position(
    longitude: 120.98,
    latitude: 14.60,
    timestamp: DateTime.utc(2026, 8, 24),
    accuracy: 5,
    altitude: 0,
    altitudeAccuracy: 1,
    heading: 0,
    headingAccuracy: 1,
    speed: 0,
    speedAccuracy: 1,
  );

  @override
  Future<CommunityLocationSearchResult?> reverseGeocode(
    double latitude,
    double longitude,
  ) async => CommunityLocationSearchResult(
    latitude: latitude,
    longitude: longitude,
    formattedAddress: 'Current Property, Manila',
    placeId: 'current-place',
  );
}

Widget picker(
  FakeLocationGateway gateway,
  ValueChanged<CommunityLocation?> onChanged,
) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(
      child: CommunityLocationPicker(
        locationService: gateway,
        onChanged: onChanged,
      ),
    ),
  ),
);

void main() {
  testWidgets('typing is debounced and suggestion selection updates location', (
    tester,
  ) async {
    final gateway = FakeLocationGateway();
    CommunityLocation? selected;
    await tester.pumpWidget(picker(gateway, (value) => selected = value));

    await tester.enterText(find.byType(TextFormField), 'Man');
    await tester.pump(const Duration(milliseconds: 499));
    expect(gateway.searchCalls, 0);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(gateway.searchCalls, 1);
    expect(find.text('Green Valley'), findsOneWidget);
    expect(find.text('Manila, Philippines'), findsOneWidget);
    await tester.tap(find.text('Green Valley'));
    await tester.pump();

    expect(selected?.formattedAddress, 'Green Valley, Manila');
    expect(selected?.placeId, 'place-green-valley');
    expect(selected?.attendanceRadiusMeters, 150);
    expect(gateway.lastResolveSessionToken, gateway.lastSearchSessionToken);
    expect(find.textContaining('14.599500'), findsOneWidget);
  });

  testWidgets('current location reverse geocode populates property address', (
    tester,
  ) async {
    final gateway = FakeLocationGateway();
    CommunityLocation? selected;
    await tester.pumpWidget(picker(gateway, (value) => selected = value));

    await tester.tap(find.text('Use Current Location'));
    await tester.pump();
    await tester.pump();

    expect(selected?.formattedAddress, 'Current Property, Manila');
    expect(selected?.placeId, 'current-place');
    expect(selected?.attendanceRadiusMeters, 150);
    expect(find.text('Current Property, Manila'), findsOneWidget);
  });
}
