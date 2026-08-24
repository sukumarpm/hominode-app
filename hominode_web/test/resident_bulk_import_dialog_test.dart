import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hominode_core/hominode_core.dart';
import 'package:hominode_web/src/services/resident_bulk_import_service.dart';
import 'package:hominode_web/src/widgets/resident_bulk_import_dialog.dart';

class _FakeGateway implements ResidentBulkImportGateway {
  final communities = <String>[];
  final rowCounts = <int>[];
  final jobIds = <String>[];

  @override
  Future<ResidentBulkImportCallResult> validate({
    required String communityId,
    required ResidentBulkImportFile file,
    String? importJobId,
  }) async {
    communities.add(communityId);
    return ResidentBulkImportCallResult(
      rows: file.rows.map((row) => {...row, 'status': 'ready'}).toList(),
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
    rowCounts.add(file.rows.length);
    jobIds.add(importJobId);
    if (rowCounts.length == 1) {
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
  testWidgets('desktop preview imports and retries only failed rows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final gateway = _FakeGateway();
    final file = ResidentBulkImportFile(
      fileName: 'residents.xlsx',
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
    await tester.pumpWidget(
      MaterialApp(
        home: ResidentBulkImportDialog(
          communityId: 'COMMUNITY_A',
          gateway: gateway,
          initialFile: file,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Alex Resident'), findsOneWidget);
    expect(find.text('Taylor Tenant'), findsOneWidget);
    expect(find.text('Valid 2'), findsOneWidget);
    expect(gateway.communities, ['COMMUNITY_A']);

    await tester.tap(find.byKey(const Key('web-import-confirm')));
    await tester.pumpAndSettle();
    expect(find.text('Confirm bulk import'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Import'));
    await tester.pumpAndSettle();

    expect(find.text('Successful 1'), findsOneWidget);
    expect(find.byKey(const Key('web-import-retry')), findsOneWidget);
    expect(gateway.rowCounts, [2]);

    await tester.tap(find.byKey(const Key('web-import-retry')));
    await tester.pumpAndSettle();
    expect(gateway.rowCounts, [2, 1]);
    expect(gateway.jobIds[1], gateway.jobIds[0]);
    expect(gateway.communities, everyElement('COMMUNITY_A'));
    expect(find.text('Successful 2'), findsOneWidget);
    expect(find.byKey(const Key('web-import-retry')), findsNothing);
  });
}
