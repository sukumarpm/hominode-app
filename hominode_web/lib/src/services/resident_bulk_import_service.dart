import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:hominode_core/hominode_core.dart';

class ResidentBulkImportCallResult {
  const ResidentBulkImportCallResult({
    required this.rows,
    required this.summary,
    this.importJobId,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
  final String? importJobId;

  int count(String field) =>
      summary[field] is num ? (summary[field] as num).toInt() : 0;

  factory ResidentBulkImportCallResult.fromCallable(Object? value) {
    if (value is! Map || value['rows'] is! List || value['summary'] is! Map) {
      throw const FormatException('The import service returned invalid data.');
    }
    return ResidentBulkImportCallResult(
      rows: (value['rows'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      summary: Map<String, dynamic>.from(value['summary'] as Map),
      importJobId: value['importJobId']?.toString(),
    );
  }
}

abstract interface class ResidentBulkImportGateway {
  Future<ResidentBulkImportCallResult> validate({
    required String communityId,
    required ResidentBulkImportFile file,
    String? importJobId,
  });

  Future<ResidentBulkImportCallResult> import({
    required String communityId,
    required ResidentBulkImportFile file,
    required String importJobId,
  });
}

class ResidentBulkImportService implements ResidentBulkImportGateway {
  ResidentBulkImportService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  static String newImportJobId() {
    final random = Random.secure();
    final suffix = List.generate(
      12,
      (_) => random.nextInt(36).toRadixString(36),
    ).join();
    return 'job_${DateTime.now().microsecondsSinceEpoch}_$suffix';
  }

  Map<String, dynamic> _payload(
    String communityId,
    ResidentBulkImportFile file,
    String? importJobId,
  ) => {
    'communityId': communityId,
    'sourceFileName': file.fileName,
    'rows': file.rows,
    'importJobId': ?importJobId,
  };

  @override
  Future<ResidentBulkImportCallResult> validate({
    required String communityId,
    required ResidentBulkImportFile file,
    String? importJobId,
  }) async => ResidentBulkImportCallResult.fromCallable(
    (await _functions
            .httpsCallable('validateResidentBulkImport')
            .call(_payload(communityId, file, importJobId)))
        .data,
  );

  @override
  Future<ResidentBulkImportCallResult> import({
    required String communityId,
    required ResidentBulkImportFile file,
    required String importJobId,
  }) async => ResidentBulkImportCallResult.fromCallable(
    (await _functions
            .httpsCallable('importResidentsBulk')
            .call(_payload(communityId, file, importJobId)))
        .data,
  );
}
