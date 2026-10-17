import 'package:admin_app/resident_bulk_import_screen.dart';
import 'package:admin_app/services/resident_bulk_import_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_core/hominode_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeGateway implements ResidentBulkImportGateway {
  final communities = <String>[];
  final importedRowCounts = <int>[];
  final jobIds = <String>[];

  @override
  Future<ResidentBulkImportCallResult> validate({
    required String communityId,
    required ResidentBulkImportFile file,
    String? importJobId,
  }) async {
    communities.add(communityId);
    return ResidentBulkImportCallResult(
      rows: [
        {...file.rows[0], 'status': 'ready'},
        {...file.rows[1], 'status': 'ready'},
      ],
      summary: const {'totalRows': 2, 'validRows': 2, 'errorRows': 0},
    );
  }

  @override
  Future<ResidentBulkImportCallResult> import({
    required String communityId,
    required ResidentBulkImportFile file,
    required String importJobId,
  }) async {
    communities.add(communityId);
    importedRowCounts.add(file.rows.length);
    jobIds.add(importJobId);
    if (importedRowCounts.length == 1) {
      return ResidentBulkImportCallResult(
        importJobId: importJobId,
        rows: [
          {...file.rows[0], 'status': 'imported'},
          {
            ...file.rows[1],
            'status': 'error',
            'code': 'row_write_failed',
            'message': 'Safe to retry.',
          },
        ],
        summary: const {'totalRows': 2, 'successCount': 1, 'failedCount': 1},
      );
    }
    return ResidentBulkImportCallResult(
      importJobId: importJobId,
      rows: [
        {...file.rows.single, 'status': 'imported'},
      ],
      summary: const {'totalRows': 1, 'successCount': 1, 'failedCount': 0},
    );
  }
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
    for (final locale in ['en', 'ta', 'hi', 'es', 'ar']) {
      await rootBundle.loadString('assets/translations/$locale.json');
    }
  });

  testWidgets(
    'previews, confirms, displays results, and retries only failed rows',
    (tester) async {
      final gateway = _FakeGateway();
      final file = ResidentBulkImportFile(
        fileName: 'residents.csv',
        rows: const [
          {
            'rowNumber': 2,
            'building': 'Tower A',
            'unit': 'A101',
            'residentName': 'Alex Resident',
            'phoneNumber': '+14155552671',
            'residentType': 'owner',
          },
          {
            'rowNumber': 3,
            'building': 'Tower A',
            'unit': 'A102',
            'residentName': 'Taylor Tenant',
            'phoneNumber': '+14155552672',
            'residentType': 'tenant',
          },
        ],
      );

      await _pumpLocalizedApp(
        tester,
        _testApp(
          ResidentBulkImportScreen(
            gateway: gateway,
            initialFile: file,
            communityId: 'COMMUNITY_A',
          ),
        ),
      );

      expect(find.text('Validation preview'), findsOneWidget);
      expect(find.textContaining('Alex Resident'), findsOneWidget);
      expect(find.textContaining('Taylor Tenant'), findsOneWidget);
      expect(gateway.communities, ['COMMUNITY_A']);

      await tester.tap(find.byKey(const Key('bulk-import-confirm')));
      await tester.pumpAndSettle();
      expect(find.text('Import residents?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Import'));
      await tester.pumpAndSettle();

      expect(find.text('Import results'), findsOneWidget);
      expect(find.byKey(const Key('bulk-import-retry')), findsOneWidget);
      expect(gateway.importedRowCounts, [2]);

      await tester.tap(find.byKey(const Key('bulk-import-retry')));
      await tester.pumpAndSettle();

      expect(gateway.importedRowCounts, [2, 1]);
      expect(gateway.jobIds[1], gateway.jobIds[0]);
      expect(gateway.communities, everyElement('COMMUNITY_A'));
      expect(find.text('Successful 2'), findsOneWidget);
      expect(find.byKey(const Key('bulk-import-retry')), findsNothing);
    },
  );

  testWidgets('bulk import labels follow the selected locale direction', (
    tester,
  ) async {
    await _pumpLocalizedApp(
      tester,
      _testApp(
        ResidentBulkImportScreen(
          gateway: _FakeGateway(),
          communityId: 'COMMUNITY_A',
        ),
        locale: const Locale('ar'),
      ),
    );

    expect(find.text('استيراد المقيمين بالجملة'), findsOneWidget);
    expect(
      Directionality.of(
        tester.element(find.text('استيراد المقيمين بالجملة')),
      ).name,
      'rtl',
    );
  });
}

Future<void> _pumpLocalizedApp(WidgetTester tester, Widget app) async {
  await tester.pumpWidget(app);
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 100)),
  );
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pumpAndSettle();
}

Widget _testApp(Widget child, {Locale locale = const Locale('en')}) {
  return EasyLocalization(
    supportedLocales: const [
      Locale('en'),
      Locale('ta'),
      Locale('hi'),
      Locale('es'),
      Locale('ar'),
    ],
    path: 'assets/translations',
    fallbackLocale: const Locale('en'),
    startLocale: locale,
    saveLocale: false,
    child: Builder(
      builder: (context) => MaterialApp(
        locale: context.locale,
        supportedLocales: context.supportedLocales,
        localizationsDelegates: context.localizationDelegates,
        home: child,
      ),
    ),
  );
}
