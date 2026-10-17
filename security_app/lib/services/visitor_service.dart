import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';

import '../models/visitor_model.dart';

abstract interface class VisitorWorkflow {
  String newOperationId();
  Future<List<VisitorModel>> getVisitors(String category);
  Future<Map<String, dynamic>> verifyVisitorCredential({
    String? qrToken,
    String? manualCode,
    required String operationId,
  });
  Future<Map<String, dynamic>> denyVisitorEntry({
    required String visitorId,
    required String reason,
    required String operationId,
  });
  Future<Map<String, dynamic>> checkoutVisitors({
    required List<String> visitorIds,
    required String operationId,
  });
}

class VisitorService implements VisitorWorkflow {
  VisitorService({FirebaseFunctions? functions, Random? random})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-southeast1'),
      _random = random ?? Random.secure();

  final FirebaseFunctions _functions;
  final Random _random;
  static const _operationAlphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-';

  static String createOperationId({Random? random}) {
    final secureRandom = random ?? Random.secure();
    return List.generate(
      32,
      (_) =>
          _operationAlphabet[secureRandom.nextInt(_operationAlphabet.length)],
    ).join();
  }

  @override
  String newOperationId() => createOperationId(random: _random);

  @override
  Future<List<VisitorModel>> getVisitors(String category) async {
    final result = await _functions.httpsCallable('listSecurityVisitors').call({
      'category': category,
    });
    final response = Map<String, dynamic>.from(result.data as Map);
    final rawVisitors = response['visitors'];
    if (rawVisitors is! List) {
      throw const FormatException('Visitor list response is invalid.');
    }
    return rawVisitors
        .whereType<Map>()
        .map(
          (visitor) =>
              VisitorModel.fromSanitizedMap(Map<String, dynamic>.from(visitor)),
        )
        .toList();
  }

  @override
  Future<Map<String, dynamic>> verifyVisitorCredential({
    String? qrToken,
    String? manualCode,
    required String operationId,
  }) async {
    if ((qrToken == null) == (manualCode == null)) {
      throw ArgumentError('Provide exactly one visitor credential.');
    }
    final result = await _functions
        .httpsCallable('verifyVisitorCredential')
        .call({
          if (qrToken != null) 'qrToken': qrToken,
          if (manualCode != null) 'manualCode': manualCode,
          'operationId': operationId,
        });
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> denyVisitorEntry({
    required String visitorId,
    required String reason,
    required String operationId,
  }) async {
    final result = await _functions.httpsCallable('denyVisitorEntry').call({
      'visitorId': visitorId,
      'reason': reason,
      'operationId': operationId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }

  @override
  Future<Map<String, dynamic>> checkoutVisitors({
    required List<String> visitorIds,
    required String operationId,
  }) async {
    final result = await _functions.httpsCallable('checkoutVisitors').call({
      'visitorIds': visitorIds,
      'operationId': operationId,
    });
    return Map<String, dynamic>.from(result.data as Map);
  }
}
