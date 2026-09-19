import 'package:cloud_functions/cloud_functions.dart';

class PublicPlatformStatsService {
  PublicPlatformStatsService({FirebaseFunctions? functions})
      : _functions =
            functions ??
            FirebaseFunctions.instanceFor(region: 'asia-southeast1');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> refresh() async {
    final response =
        await _functions.httpsCallable('refreshPublicPlatformStats').call();

    final data = response.data;

    if (data is! Map || data['success'] != true || data['stats'] is! Map) {
      throw StateError(
        'Public platform statistics returned an invalid response.',
      );
    }

    return Map<String, dynamic>.from(data['stats'] as Map);
  }
}
