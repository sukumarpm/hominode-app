import 'dart:convert';

import 'package:excel/excel.dart';
import 'package:hominode_core/hominode_core.dart';
import 'package:test/test.dart';

void main() {
  test('parses normalized CSV headers and quoted values', () {
    final parsed = ResidentBulkImportParser.parseBytes(
      'residents.csv',
      utf8.encode(
        'Building Name,Flat Number,Full Name,Mobile,Ownership Type,Email Address,Country Code\n'
        'Tower A,A101,"Resident, Alex",+14155552671,owner,alex@example.com,US\n',
      ),
    );
    expect(parsed.rowCount, 1);
    expect(parsed.rows.single, containsPair('residentName', 'Resident, Alex'));
    expect(parsed.rows.single, containsPair('rowNumber', 2));
    expect(parsed.rows.single, containsPair('residentType', 'owner'));
  });

  test('parses the first XLSX worksheet', () {
    final workbook = Excel.createExcel();
    final sheet = workbook[workbook.getDefaultSheet()!];
    sheet.appendRow(
      residentBulkImportRequiredColumns.map(TextCellValue.new).toList(),
    );
    sheet.appendRow(
      [
        'Tower A',
        'A101',
        'Alex Resident',
        '+14155552671',
        'owner',
      ].map(TextCellValue.new).toList(),
    );
    final bytes = workbook.encode()!;
    final parsed = ResidentBulkImportParser.parseBytes('residents.xlsx', bytes);
    expect(parsed.rows.single['building'], 'Tower A');
    expect(parsed.rows.single['phoneNumber'], '+14155552671');
  });

  test('rejects missing, duplicate, and unsupported columns', () {
    for (final csv in [
      'building,unit,residentName,phoneNumber\nA,A1,Alex,+14155552671\n',
      'building,unit,residentName,phoneNumber,residentType,phone\nA,A1,Alex,+14155552671,owner,+14155552671\n',
      'building,unit,residentName,phoneNumber,residentType,role\nA,A1,Alex,+14155552671,owner,admin\n',
    ]) {
      expect(
        () => ResidentBulkImportParser.parseBytes(
          'residents.csv',
          utf8.encode(csv),
        ),
        throwsA(isA<ResidentBulkImportParseException>()),
      );
    }
  });

  test('rejects files over the 500 row limit', () {
    final csv = StringBuffer(
      '${residentBulkImportRequiredColumns.join(',')}\n',
    );
    for (var index = 0; index < 501; index++) {
      csv.writeln(
        'Tower A,A$index,Resident $index,+1415555${index.toString().padLeft(4, '0')},owner',
      );
    }
    expect(
      () => ResidentBulkImportParser.parseBytes(
        'residents.csv',
        utf8.encode(csv.toString()),
      ),
      throwsA(
        isA<ResidentBulkImportParseException>().having(
          (error) => error.code,
          'code',
          'too_many_rows',
        ),
      ),
    );
  });

  test('result export guards spreadsheet formula injection', () {
    final csv = utf8.decode(
      ResidentBulkImportParser.resultCsvBytes([
        {
          'rowNumber': 2,
          'residentName': '=HYPERLINK("bad")',
          'status': 'error',
        },
      ]),
    );
    expect(csv, contains("'=HYPERLINK"));
  });
}
