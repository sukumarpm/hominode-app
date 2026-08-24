import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';

const residentBulkImportRequiredColumns = <String>[
  'building',
  'unit',
  'residentName',
  'phoneNumber',
  'residentType',
];

const residentBulkImportOptionalColumns = <String>[
  'email',
  'countryCode',
  'alternatePhone',
  'moveInDate',
];

const residentBulkImportColumns = <String>[
  ...residentBulkImportRequiredColumns,
  ...residentBulkImportOptionalColumns,
];

class ResidentBulkImportParseException implements Exception {
  const ResidentBulkImportParseException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

class ResidentBulkImportFile {
  const ResidentBulkImportFile({required this.fileName, required this.rows});

  final String fileName;
  final List<Map<String, dynamic>> rows;

  int get rowCount => rows.length;
}

class ResidentBulkImportParser {
  const ResidentBulkImportParser._();

  static const maxRows = 500;

  static ResidentBulkImportFile parseBytes(String fileName, List<int> bytes) {
    final extension = fileName.split('.').last.toLowerCase();
    final cells = switch (extension) {
      'csv' => _parseCsv(bytes),
      'xlsx' => _parseXlsx(bytes),
      _ => throw const ResidentBulkImportParseException(
        'unsupported_file_type',
        'Select a CSV or XLSX file.',
      ),
    };
    return ResidentBulkImportFile(fileName: fileName, rows: _mapRows(cells));
  }

  static Uint8List templateCsvBytes() => Uint8List.fromList(
    utf8.encode(
      '${residentBulkImportColumns.join(',')}\r\n'
      'Tower A,A101,Alex Resident,+14155552671,owner,alex@example.com,US,,2026-08-25\r\n'
      'Tower A,A102,Taylor Tenant,+14155552672,tenant,,US,,2026-09-01\r\n',
    ),
  );

  static Uint8List resultCsvBytes(List<Map<String, dynamic>> rows) {
    const columns = [
      'rowNumber',
      'residentName',
      'phoneNumber',
      'building',
      'unit',
      'status',
      'code',
      'message',
    ];
    final buffer = StringBuffer('${columns.join(',')}\r\n');
    for (final row in rows) {
      buffer.writeln(columns.map((column) => _csvCell(row[column])).join(','));
    }
    return Uint8List.fromList(utf8.encode(buffer.toString()));
  }

  static List<List<String>> _parseCsv(List<int> bytes) {
    late final String input;
    try {
      input = utf8.decode(bytes).replaceFirst('\ufeff', '');
    } on FormatException {
      throw const ResidentBulkImportParseException(
        'invalid_encoding',
        'The CSV file must use UTF-8 encoding.',
      );
    }
    final rows = <List<String>>[];
    var row = <String>[];
    var cell = StringBuffer();
    var quoted = false;
    for (var index = 0; index < input.length; index++) {
      final character = input[index];
      if (quoted) {
        if (character == '"') {
          if (index + 1 < input.length && input[index + 1] == '"') {
            cell.write('"');
            index++;
          } else {
            quoted = false;
          }
        } else {
          cell.write(character);
        }
        continue;
      }
      if (character == '"' && cell.isEmpty) {
        quoted = true;
      } else if (character == ',') {
        row.add(cell.toString());
        cell = StringBuffer();
      } else if (character == '\n' || character == '\r') {
        if (character == '\r' &&
            index + 1 < input.length &&
            input[index + 1] == '\n') {
          index++;
        }
        row.add(cell.toString());
        rows.add(row);
        row = <String>[];
        cell = StringBuffer();
      } else {
        cell.write(character);
      }
    }
    if (quoted) {
      throw const ResidentBulkImportParseException(
        'malformed_csv',
        'The CSV contains an unclosed quoted value.',
      );
    }
    if (cell.isNotEmpty || row.isNotEmpty) {
      row.add(cell.toString());
      rows.add(row);
    }
    return rows;
  }

  static List<List<String>> _parseXlsx(List<int> bytes) {
    try {
      final workbook = Excel.decodeBytes(bytes);
      if (workbook.tables.isEmpty) {
        throw const ResidentBulkImportParseException(
          'empty_file',
          'The workbook does not contain a worksheet.',
        );
      }
      final sheet = workbook.tables.values.first;
      return sheet.rows
          .map(
            (row) => row
                .map((cell) => cell?.value?.toString().trim() ?? '')
                .toList(growable: false),
          )
          .toList(growable: false);
    } on ResidentBulkImportParseException {
      rethrow;
    } catch (_) {
      throw const ResidentBulkImportParseException(
        'malformed_xlsx',
        'The XLSX workbook could not be read.',
      );
    }
  }

  static List<Map<String, dynamic>> _mapRows(List<List<String>> cells) {
    final nonEmpty = cells
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .toList();
    if (nonEmpty.isEmpty) {
      throw const ResidentBulkImportParseException(
        'empty_file',
        'The import file is empty.',
      );
    }
    final headers = <String>[];
    final seen = <String>{};
    for (final rawHeader in nonEmpty.first) {
      final header = _canonicalHeader(rawHeader);
      if (header == null) {
        throw ResidentBulkImportParseException(
          'unsupported_header',
          'Unsupported column: ${rawHeader.trim().isEmpty ? '(blank)' : rawHeader.trim()}.',
        );
      }
      if (!seen.add(header)) {
        throw ResidentBulkImportParseException(
          'duplicate_header',
          'The $header column appears more than once.',
        );
      }
      headers.add(header);
    }
    final missing = residentBulkImportRequiredColumns
        .where((column) => !seen.contains(column))
        .toList();
    if (missing.isNotEmpty) {
      throw ResidentBulkImportParseException(
        'missing_columns',
        'Missing required columns: ${missing.join(', ')}.',
      );
    }
    final rows = <Map<String, dynamic>>[];
    for (var rowIndex = 1; rowIndex < nonEmpty.length; rowIndex++) {
      final source = nonEmpty[rowIndex];
      if (source.length > headers.length &&
          source.skip(headers.length).any((cell) => cell.trim().isNotEmpty)) {
        throw ResidentBulkImportParseException(
          'malformed_row',
          'Row ${rowIndex + 1} contains more values than the header.',
        );
      }
      final row = <String, dynamic>{'rowNumber': rowIndex + 1};
      for (var columnIndex = 0; columnIndex < headers.length; columnIndex++) {
        row[headers[columnIndex]] = columnIndex < source.length
            ? source[columnIndex].trim()
            : '';
      }
      rows.add(row);
    }
    if (rows.isEmpty) {
      throw const ResidentBulkImportParseException(
        'empty_file',
        'The import file has headers but no resident rows.',
      );
    }
    if (rows.length > maxRows) {
      throw const ResidentBulkImportParseException(
        'too_many_rows',
        'A maximum of 500 resident rows may be imported at once.',
      );
    }
    return List.unmodifiable(
      rows.map((row) => Map<String, dynamic>.unmodifiable(row)),
    );
  }

  static String? _canonicalHeader(String value) {
    final normalized = value.trim().toLowerCase().replaceAll(
      RegExp(r'[^a-z0-9]'),
      '',
    );
    return const {
      'building': 'building',
      'buildingname': 'building',
      'tower': 'building',
      'block': 'building',
      'unit': 'unit',
      'flat': 'unit',
      'flatnumber': 'unit',
      'unitnumber': 'unit',
      'apartment': 'unit',
      'residentname': 'residentName',
      'fullname': 'residentName',
      'name': 'residentName',
      'phonenumber': 'phoneNumber',
      'phone': 'phoneNumber',
      'mobile': 'phoneNumber',
      'mobilenumber': 'phoneNumber',
      'residenttype': 'residentType',
      'ownershiptype': 'residentType',
      'occupancytype': 'residentType',
      'email': 'email',
      'emailaddress': 'email',
      'countrycode': 'countryCode',
      'alternatephone': 'alternatePhone',
      'alternatephonenumber': 'alternatePhone',
      'moveindate': 'moveInDate',
    }[normalized];
  }

  static String _csvCell(Object? value) {
    var result = value?.toString() ?? '';
    if (RegExp(r'^[=+\-@]').hasMatch(result)) result = "'$result";
    if (result.contains(',') ||
        result.contains('"') ||
        result.contains('\n') ||
        result.contains('\r')) {
      result = '"${result.replaceAll('"', '""')}"';
    }
    return result;
  }
}
