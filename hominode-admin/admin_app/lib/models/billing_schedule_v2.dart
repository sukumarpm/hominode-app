import 'dart:math';

const int maxSafeBillingMinorAmountV2 = 9007199254740991;

class BillingScheduleTargetV2 {
  final String id;
  final String label;
  final String? buildingId;

  const BillingScheduleTargetV2({
    required this.id,
    required this.label,
    this.buildingId,
  });
}

class BillingScheduleCreatedV2 {
  final String scheduleId;
  final String revisionId;
  final int revisionNo;
  final bool alreadyCompleted;

  const BillingScheduleCreatedV2({
    required this.scheduleId,
    required this.revisionId,
    required this.revisionNo,
    required this.alreadyCompleted,
  });
}

abstract interface class BillingScheduleV2Gateway {
  Future<List<BillingScheduleTargetV2>> loadBillingScheduleBuildings(
    String communityId,
  );

  Future<List<BillingScheduleTargetV2>> loadBillingScheduleUnits(
    String communityId,
  );

  Future<BillingScheduleCreatedV2> createBillingScheduleV2(
    Map<String, dynamic> request,
  );
}

int? parseBillingScheduleRupeesToMinorUnits(String input) {
  final match = RegExp(r'^(\d+)(?:\.(\d{1,2}))?$').firstMatch(input.trim());
  if (match == null) return null;
  final rupees = int.tryParse(match.group(1)!);
  if (rupees == null || rupees > maxSafeBillingMinorAmountV2 ~/ 100) {
    return null;
  }
  final paise = int.tryParse((match.group(2) ?? '').padRight(2, '0')) ?? 0;
  final amount = rupees * 100 + paise;
  return amount > 0 && amount <= maxSafeBillingMinorAmountV2 ? amount : null;
}

String createBillingScheduleIdempotencyKeyV2({Random? random}) {
  final source = random ?? Random.secure();
  final bytes = List<int>.generate(24, (_) => source.nextInt(256));
  final token = bytes
      .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
      .join();
  return 'schedule_$token';
}

Map<String, dynamic> validateBillingScheduleRequestV2(Object? raw) {
  if (raw is! Map) throw const FormatException('Invalid recurring schedule.');
  final request = Map<String, dynamic>.from(raw);
  const allowed = {
    'schemaVersion',
    'communityId',
    'currency',
    'frequency',
    'idempotencyKey',
    'scope',
    'buildingId',
    'flatId',
    'flatIds',
    'generationDay',
    'dueDay',
    'startBillingPeriod',
    'endBillingPeriod',
    'chargeLines',
  };
  if (request.keys.any((key) => !allowed.contains(key))) {
    throw const FormatException(
      'Recurring schedule contains unsupported fields.',
    );
  }
  if (!request.containsKey('endBillingPeriod')) {
    throw const FormatException(
      'End billing period must be provided or left blank.',
    );
  }
  bool validId(Object? value) =>
      value is String &&
      value.isNotEmpty &&
      value == value.trim() &&
      value.length <= 128 &&
      !value.contains('/') &&
      !RegExp(r'[\x00-\x1f\x7f]').hasMatch(value) &&
      value != '.' &&
      value != '..' &&
      !RegExp(r'^__.*__$').hasMatch(value);

  if (request['schemaVersion'] != 2 ||
      request['currency'] != 'INR' ||
      request['frequency'] != 'monthly' ||
      !validId(request['communityId']) ||
      !validId(request['idempotencyKey']) ||
      !RegExp(
        r'^[A-Za-z0-9_-]{1,128}$',
      ).hasMatch(request['idempotencyKey'] as String)) {
    throw const FormatException('Recurring schedule identity is invalid.');
  }

  final scope = request['scope'];
  if (!const {'community', 'building', 'unit', 'units'}.contains(scope)) {
    throw const FormatException('Recurring schedule scope is invalid.');
  }
  if ((scope == 'building' || scope == 'unit') &&
      !validId(request['buildingId'])) {
    throw const FormatException('Select a valid building.');
  }
  if ((scope == 'unit' && !validId(request['flatId'])) ||
      (scope != 'unit' && request.containsKey('flatId')) ||
      (scope != 'building' &&
          scope != 'unit' &&
          request.containsKey('buildingId'))) {
    throw const FormatException(
      'Recurring schedule scope identifiers are invalid.',
    );
  }

  if (scope == 'units') {
    final ids = request['flatIds'];
    if (ids is! List ||
        ids.isEmpty ||
        ids.length > 5000 ||
        ids.any((id) => !validId(id)) ||
        ids.toSet().length != ids.length) {
      throw const FormatException('Select valid units (up to 5,000).');
    }
  } else if (request.containsKey('flatIds')) {
    throw const FormatException(
      'Unit selection does not match the schedule scope.',
    );
  }

  int? day(String key) {
    final value = request[key];
    return value is int && value >= 1 && value <= 28 ? value : null;
  }

  final generationDay = day('generationDay');
  final dueDay = day('dueDay');
  if (generationDay == null || dueDay == null || dueDay < generationDay) {
    throw const FormatException(
      'Generation and due days must be from 1 to 28, with due day on or after generation day.',
    );
  }

  bool validPeriod(Object? value) =>
      value is String &&
      RegExp(r'^(20\d{2}|2100)-(0[1-9]|1[0-2])$').hasMatch(value);
  final start = request['startBillingPeriod'];
  final end = request['endBillingPeriod'];
  if (!validPeriod(start) ||
      (end != null &&
          (!validPeriod(end) ||
              (end as String).compareTo(start as String) < 0))) {
    throw const FormatException('Use valid billing periods in YYYY-MM format.');
  }

  final rawLines = request['chargeLines'];
  if (rawLines is! List || rawLines.isEmpty || rawLines.length > 20) {
    throw const FormatException('Add between 1 and 20 recurring charge lines.');
  }
  final lineIds = <String>{};
  final labels = <String>{};
  var total = 0;
  for (final rawLine in rawLines) {
    if (rawLine is! Map) {
      throw const FormatException('A charge line is invalid.');
    }
    final line = Map<String, dynamic>.from(rawLine);
    final lineId = line['lineId'];
    final code = line['code'];
    final label = line['label'];
    final amount = line['amountMinor'];
    const standard = {
      'maintenance': 'Maintenance',
      'water': 'Water',
      'parking': 'Parking',
      'service': 'Service',
      'electricity': 'Electricity',
      'security': 'Security',
      'other': 'Other',
    };
    if (!validId(lineId) || !lineIds.add(lineId as String)) {
      throw const FormatException('Each charge line needs a unique ID.');
    }
    if ((code != 'custom' && standard[code] != label) ||
        (code == 'custom' &&
            (label is! String ||
                label.replaceAll(RegExp(r'\s+'), ' ').trim().isEmpty ||
                label.replaceAll(RegExp(r'\s+'), ' ').trim().length > 80 ||
                standard.values.any(
                  (standardLabel) =>
                      standardLabel.toLowerCase() ==
                      label
                          .replaceAll(RegExp(r'\s+'), ' ')
                          .trim()
                          .toLowerCase(),
                ))) ||
        (code != 'custom' && !standard.containsKey(code))) {
      throw const FormatException(
        'A recurring charge type or label is invalid.',
      );
    }
    final normalizedLabel = (label as String)
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toLowerCase();
    if (!labels.add(normalizedLabel)) {
      throw const FormatException('Recurring charge labels must be unique.');
    }
    if (amount is! int || amount < 0 || amount > maxSafeBillingMinorAmountV2) {
      throw const FormatException(
        'Charge amounts must be valid whole paise amounts.',
      );
    }
    total += amount;
    if (total > maxSafeBillingMinorAmountV2) {
      throw const FormatException('The recurring charge total is too large.');
    }
  }
  if (total == 0) {
    throw const FormatException('The recurring total must be positive.');
  }
  return request;
}
