import 'dart:convert';
import 'dart:math';

import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

import '../../../core/firebase/firebase_app_check_provider.dart';
import '../data/family_chat_database.dart';
import '../data/family_chat_notification_platform.dart';

String familyChatRevocationToken() {
  final random = Random.secure();
  return base64Url
      .encode(List<int>.generate(32, (_) => random.nextInt(256)))
      .replaceAll('=', '');
}

class FamilyChatRegistrationJournal {
  const FamilyChatRegistrationJournal(this.db);
  final FamilyChatDatabase db;
  Future<String> prepare(
    String uid,
    String scope,
    Map<String, dynamic> registration,
  ) async {
    final key =
        'deviceRegistration:${registration['installationId']}:${registration['counter']}';
    await db.setMetadata(key, {
      'uid': uid,
      'scope': scope,
      'registration': registration,
      'createdAt': DateTime.now().millisecondsSinceEpoch,
    });
    return key;
  }

  Future<void> confirm(String key) => db.transaction(() async {
    final entry = await db.metadata(key);
    if (entry == null) return;
    final registration = entry['registration'] as Map;
    await db.setMetadata(key, {...entry, 'confirmed': true});
    final rows = await db
        .customSelect(
          "SELECT key,value FROM chat_metadata WHERE substr(key,1,19)='deviceRegistration:'",
        )
        .get();
    for (final row in rows) {
      final old = jsonDecode(row.read<String>('value')) as Map;
      final value = old['registration'] as Map;
      if (old['uid'] == entry['uid'] &&
          value['installationId'] == registration['installationId'] &&
          value['token'] == registration['token'] &&
          (value['counter'] as int) < (registration['counter'] as int)) {
        await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
          row.read<String>('key'),
        ]);
      }
    }
  });
  Future<void> revokeObsolete({
    required String? currentUid,
    required bool enabled,
    String? currentScope,
    required Future<Map<String, dynamic>> Function(Map<String, dynamic>) revoke,
  }) async {
    final rows = await db
        .customSelect(
          "SELECT key,value FROM chat_metadata WHERE substr(key,1,19)='deviceRegistration:'",
        )
        .get();
    final entries = [
      for (final row in rows)
        (
          key: row.read<String>('key'),
          entry: Map<String, dynamic>.from(
            jsonDecode(row.read<String>('value')) as Map,
          ),
        ),
    ];
    for (final row in entries) {
      final entry = row.entry, value = row.entry['registration'] as Map;
      final newer = entries.any(
        (other) =>
            other.entry['confirmed'] == true &&
            other.entry['uid'] == entry['uid'] &&
            (other.entry['registration'] as Map)['installationId'] ==
                value['installationId'] &&
            ((other.entry['registration'] as Map)['counter'] as int) >
                (value['counter'] as int),
      );
      if (!newer &&
          enabled &&
          entry['uid'] == currentUid &&
          (currentScope == null || entry['scope'] == currentScope)) {
        continue;
      }
      final registration = Map<String, dynamic>.from(
        entry['registration'] as Map,
      )..remove('enabled');
      final response = await revoke(registration);
      if (response['ok'] == true) {
        await db.customStatement('DELETE FROM chat_metadata WHERE key=?', [
          row.key,
        ]);
      }
    }
  }
}

/// App attestation plus a one-registration capability; no old login is needed.
Future<Map<String, dynamic>> revokeFamilyChatDevice(
  Map<String, dynamic> data,
) async {
  await FirebaseAppCheck.instance.activate(
    providerAndroid: await createAndroidAppCheckProvider(),
  );
  final appCheck = await FirebaseAppCheck.instance.getToken();
  if (appCheck == null || appCheck.isEmpty) {
    throw StateError('Device attestation unavailable');
  }
  final response = await http
      .post(
        Uri.https(
          'europe-west1-${Firebase.app().options.projectId}.cloudfunctions.net',
          '/revokeFamilyChatNotifications',
        ),
        headers: {
          'Content-Type': 'application/json',
          'X-Firebase-AppCheck': appCheck,
        },
        body: jsonEncode({'data': data}),
      )
      .timeout(const Duration(seconds: 20));
  final body = jsonDecode(response.body) as Map;
  if (response.statusCode != 200 || body['error'] != null) {
    throw StateError('Device revocation is pending');
  }
  return Map<String, dynamic>.from(body['result'] as Map);
}

Future<void> disableFamilyChatRollout(
  FamilyChatDatabase db, {
  Future<Map<String, dynamic>> Function(Map<String, dynamic>) revoke =
      revokeFamilyChatDevice,
  bool Function()? keepTrying,
}) async {
  final notices = await db.deactivateChat();
  await FamilyChatNotificationPlatform.cancel(
    db,
    notices,
    keepTrying: keepTrying,
  );
  await FamilyChatRegistrationJournal(
    db,
  ).revokeObsolete(currentUid: null, enabled: false, revoke: revoke);
}
