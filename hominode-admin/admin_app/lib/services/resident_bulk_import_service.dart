import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:hominode_core/hominode_core.dart' show ResidentBulkImportFile;

class ResidentBulkImportCallResult {
  const ResidentBulkImportCallResult({
    required this.rows,
    required this.summary,
    this.importJobId,
  });

  final List<Map<String, dynamic>> rows;
  final Map<String, dynamic> summary;
  final String? importJobId;

  int get totalRows => _number(summary['totalRows']);
  int get validRows => _number(summary['validRows']);
  int get errorRows => _number(summary['errorRows']);
  int get successCount => _number(summary['successCount']);
  int get failedCount => _number(summary['failedCount']);

  static int _number(Object? value) => value is num ? value.toInt() : 0;

  factory ResidentBulkImportCallResult.fromCallable(Object? value) {
    if (value is! Map) {
      throw const FormatException('The import service returned invalid data.');
    }
    final data = Map<String, dynamic>.from(value);
    final rawRows = data['rows'];
    final rawSummary = data['summary'];
    if (rawRows is! List || rawSummary is! Map) {
      throw const FormatException('The import service returned invalid data.');
    }
    return ResidentBulkImportCallResult(
      rows: rawRows
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList(growable: false),
      summary: Map<String, dynamic>.from(rawSummary),
      importJobId: data['importJobId']?.toString(),
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

  Map<String, dynamic> _payload({
    required String communityId,
    required ResidentBulkImportFile file,
    String? importJobId,
  }) => {
    'communityId': communityId,
    'sourceFileName': file.fileName,
    'rows': file.rows,
    if (importJobId != null) 'importJobId': importJobId,
  };

  @override
  Future<ResidentBulkImportCallResult> validate({
    required String communityId,
    required ResidentBulkImportFile file,
    String? importJobId,
  }) async {
    final response = await _functions
        .httpsCallable('validateResidentBulkImport')
        .call(
          _payload(
            communityId: communityId,
            file: file,
            importJobId: importJobId,
          ),
        );
    return ResidentBulkImportCallResult.fromCallable(response.data);
  }

  @override
  Future<ResidentBulkImportCallResult> import({
    required String communityId,
    required ResidentBulkImportFile file,
    required String importJobId,
  }) async {
    final response = await _functions
        .httpsCallable('importResidentsBulk')
        .call(
          _payload(
            communityId: communityId,
            file: file,
            importJobId: importJobId,
          ),
        );
    return ResidentBulkImportCallResult.fromCallable(response.data);
  }
}
