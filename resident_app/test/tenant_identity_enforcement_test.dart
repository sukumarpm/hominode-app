import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:resident_app/src/models/tenant_profile.dart';
import 'package:resident_app/src/screens/resident_identity_verification_screen.dart';
import 'package:resident_app/src/services/firebase_auth_service.dart';
import 'package:resident_app/src/services/flat_access_control_service.dart';
import 'package:resident_app/src/services/resident_identity_service.dart';
import 'package:resident_app/src/services/resident_auth_routing.dart';
import 'package:resident_app/src/services/tenant_resolution_service.dart';
import 'package:resident_app/src/widgets/flat_access_wrapper.dart';

Map<String, dynamic> resident({
  String type = 'tenant',
  String status = 'verification_required',
  bool verified = false,
}) => {
  'uid': 'resident',
  'phoneNumber': '+639171100000',
  'role': 'resident',
  'communityId': 'A',
  'residentType': type,
  'ownershipType': type,
  'approvalStatus': 'approved',
  'isActive': true,
  'status': 'active',
  'occupancyStatus': 'current',
  'flatId': 'unit',
  'buildingId': 'building',
  'identityVerified': verified,
  'identityVerificationStatus': status,
};

class _Token extends Fake implements IdTokenResult {
  @override
  String get signInProvider => 'phone';
}

class _User extends Fake implements User {
  Future<void> Function()? reloadAction;
  @override
  String get uid => 'resident';
  @override
  String get phoneNumber => '+639171100000';
  @override
  Future<IdTokenResult> getIdTokenResult([bool forceRefresh = false]) async =>
      _Token();
  @override
  Future<void> reload() async => reloadAction?.call();
}

class _Auth extends Fake implements FirebaseAuth {
  final user = _User();
  int signOutCount = 0;
  @override
  User get currentUser => user;
  @override
  Future<void> signOut() async => signOutCount++;
}

class _Store extends Fake implements FirebaseFirestore {}

class _Functions extends Fake implements FirebaseFunctions {}

class _Resolver extends Fake implements TenantResolutionService {
  _Resolver(this.data);
  final Map<String, dynamic> data;
  bool cleared = false;
  @override
  void clear() => cleared = true;
  @override
  Future<TenantProfile?> loadAuthenticatedProfile() async =>
      TenantProfile.fromMap('resident', data);
}

class _Proofs extends ResidentIdentityService {
  _Proofs()
    : super(auth: _Auth(), firestore: _Store(), functions: _Functions());
  final updates = StreamController<Map<String, dynamic>>.broadcast();
  var current = resident();
  int uploads = 0;
  @override
  Stream<Map<String, dynamic>> watchProfile() async* {
    yield current;
    yield* updates.stream;
  }

  @override
  Future<void> upload(XFile file) async {
    uploads++;
    current = resident(status: 'pending');
    updates.add(current);
  }
}

void main() {
  test(
    'Home requires explicit Tenant verification and preserves optional-proof Owners',
    () {
      for (final status in [
        'verification_required',
        'pending',
        'rejected',
        'not_required',
        'unknown',
      ]) {
        final result = FlatAccessControlService.evaluateApprovedProfile(
          resident(status: status, verified: true),
        );
        expect(result.hasAccess, false, reason: status);
        expect(result.identityVerificationRequired, true);
      }
      final missing = resident(verified: true)
        ..remove('identityVerificationStatus');
      expect(
        FlatAccessControlService.evaluateApprovedProfile(missing).hasAccess,
        false,
      );
      expect(
        FlatAccessControlService.evaluateApprovedProfile(
          resident(status: 'verified', verified: true),
        ).hasAccess,
        true,
      );
      expect(
        FlatAccessControlService.evaluateApprovedProfile(
          resident(type: 'owner', status: 'not_required'),
        ).hasAccess,
        true,
      );
    },
  );

  test(
    'restart restores pending or rejected Tenants to proof flow with the same Phone Auth session',
    () async {
      final auth = _Auth();
      final service = FirebaseAuthService.forTesting(
        auth: auth,
        deactivateNotifications: () async {},
      );
      for (final status in ['verification_required', 'pending', 'rejected']) {
        for (final active in [true, false]) {
          final result = await service.restoreResidentSession(
            _Resolver({...resident(status: status), 'isActive': active}),
          );
          expect(result.state, ResidentAuthState.identityVerificationRequired);
          expect(result.user, same(auth.user));
        }
      }
    },
  );

  test('deleted cached Auth session is cleared and routed to login', () async {
    final auth = _Auth()
      ..user.reloadAction = () async {
        throw FirebaseAuthException(code: 'user-not-found');
      };
    final service = FirebaseAuthService.forTesting(
      auth: auth,
      deactivateNotifications: () async {},
    );

    final result = await service.restoreResidentSession(_Resolver(resident()));

    expect(result.success, isFalse);
    expect(result.errorCode, 'user-not-found');
    expect(ResidentAuthRouting.routeFor(result), '/login');
    expect(auth.signOutCount, 1);
  });

  test(
    'temporary Auth validation failure preserves cached session for retry',
    () async {
      final auth = _Auth()
        ..user.reloadAction = () async {
          throw FirebaseAuthException(code: 'network-request-failed');
        };
      final service = FirebaseAuthService.forTesting(
        auth: auth,
        deactivateNotifications: () async {},
      );

      final result = await service.restoreResidentSession(
        _Resolver(resident()),
      );

      expect(result.success, isFalse);
      expect(result.errorCode, 'network-request-failed');
      expect(ResidentAuthRouting.routeFor(result), '/login');
      expect(auth.signOutCount, 0);
    },
  );

  testWidgets(
    'direct Home navigation after policy acceptance redirects unverified Tenant to existing proof route',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: FlatAccessWrapper(
            accessStream: Stream.value(
              FlatAccessControlService.evaluateApprovedProfile(resident()),
            ),
            child: const Text('Protected Home'),
          ),
          routes: {
            '/resident-identity-verification': (_) =>
                const Scaffold(body: Text('Existing proof route')),
          },
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Protected Home'), findsNothing);
      expect(find.text('Existing proof route'), findsOneWidget);
      expect(
        Navigator.of(
          tester.element(find.text('Existing proof route')),
        ).canPop(),
        false,
      );
    },
  );

  testWidgets(
    'Tenant uploads, waits, corrects rejected proof and continues after approval without OTP',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final proofs = _Proofs();
      addTearDown(proofs.updates.close);
      var accessChecks = 0;
      await tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(390, 844),
          builder: (_, _) => MaterialApp(
            home: Builder(
              builder: (context) => ResidentIdentityVerificationScreen(
                service: proofs,
                pickProof: () async =>
                    XFile.fromData(Uint8List.fromList([1]), name: 'proof.png'),
                onCheckAccess: () async {
                  accessChecks++;
                  if (FlatAccessControlService.evaluateApprovedProfile(
                    proofs.current,
                  ).hasAccess) {
                    Navigator.of(
                      context,
                    ).pushNamedAndRemoveUntil('/home', (_) => false);
                  }
                },
              ),
            ),
            routes: {
              '/home': (_) => const Scaffold(body: Text('Protected Home')),
            },
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Upload identity proof'));
      await tester.pumpAndSettle();
      expect(proofs.uploads, 1);
      expect(find.textContaining('awaiting Admin review'), findsOneWidget);
      await tester.tap(find.text('Check verification status'));
      await tester.pumpAndSettle();
      expect(find.text('Protected Home'), findsNothing);
      proofs.current = {
        ...resident(status: 'rejected'),
        'identityVerificationRejectionReason': 'Image is unclear',
      };
      proofs.updates.add(proofs.current);
      await tester.pumpAndSettle();
      expect(find.text('Admin note: Image is unclear'), findsOneWidget);
      await tester.tap(find.text('Upload a new proof'));
      await tester.pumpAndSettle();
      expect(proofs.uploads, 2);
      proofs.current = resident(status: 'verified', verified: true);
      proofs.updates.add(proofs.current);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check verification status'));
      await tester.pumpAndSettle();
      expect(find.text('Protected Home'), findsOneWidget);
      expect(accessChecks, 2);
    },
  );
}
