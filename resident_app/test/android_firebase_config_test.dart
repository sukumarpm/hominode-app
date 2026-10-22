import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Android Firebase resources use the registered Resident app config', () {
    final strings = File(
      'android/app/src/main/res/values/strings.xml',
    ).readAsStringSync();
    const firebaseManagedResourceNames = <String>[
      'default_web_client_id',
      'firebase_database_url',
      'gcm_defaultSenderId',
      'google_api_key',
      'google_app_id',
      'google_crash_reporting_api_key',
      'google_storage_bucket',
      'project_id',
    ];
    for (final name in firebaseManagedResourceNames) {
      expect(strings, isNot(contains('name="$name"')), reason: name);
    }

    final config =
        jsonDecode(File('android/app/google-services.json').readAsStringSync())
            as Map<String, dynamic>;
    final project = config['project_info'] as Map<String, dynamic>;
    final clients = config['client'] as List<dynamic>;
    final residentClient = clients.cast<Map<String, dynamic>>().singleWhere(
      (client) =>
          (client['client_info'] as Map<String, dynamic>)['android_client_info']
              is Map<String, dynamic> &&
          ((client['client_info']
                      as Map<String, dynamic>)['android_client_info']
                  as Map<String, dynamic>)['package_name'] ==
              'com.marantrix.hominode.resident',
    );
    final clientInfo = residentClient['client_info'] as Map<String, dynamic>;
    final appId = clientInfo['mobilesdk_app_id'] as String;
    final options = File('lib/firebase_options.dart').readAsStringSync();

    expect(project['project_id'], 'hominode-prod');
    expect(options, contains("appId: '$appId'"));
    expect(options, contains("projectId: '${project['project_id']}'"));
  });
}
