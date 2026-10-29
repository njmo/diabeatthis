import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:diabeatthis/core/notifications/domain/models/hash_notification_id_factory.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_event_type.dart';
import 'package:diabeatthis/core/notifications/domain/models/notification_key.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const factory = HashNotificationIdFactory();
  const keys = [
    NotificationKey(type: NotificationEventType.tempTarget, entityId: 13),
    NotificationKey(type: NotificationEventType.eatNow, entityId: 42),
    NotificationKey(type: NotificationEventType.activityFinished, entityId: 7),
  ];
  // These values form the persisted OS identifier contract, including after an
  // enum gains new cases or execution moves to the background isolate.
  const expectedIds = [684434231, 1595002650, 1176173470];

  test('notification IDs retain their persisted contract', () {
    expect(keys.map(factory.create), expectedIds);
    expect(
      factory.create(
        const NotificationKey(
          type: NotificationEventType.tempTarget,
          entityId: 14,
        ),
      ),
      isNot(expectedIds.first),
    );
  });

  test('background isolate computes the same notification IDs', () async {
    final ids = await Isolate.run(() => keys.map(factory.create).toList());
    expect(ids, expectedIds);
  });

  test('fresh processes compute the same persisted notification IDs', () async {
    final directory = await Directory.systemTemp.createTemp(
      'notification_ids_',
    );
    try {
      final modelRoot = Directory(
        'lib/core/notifications/domain/models',
      ).absolute.uri;
      final script = File('${directory.path}/notification_ids.dart');
      await script.writeAsString('''
import 'dart:convert';
import '${modelRoot.resolve('hash_notification_id_factory.dart')}';
import '${modelRoot.resolve('notification_key.dart')}';
import '${modelRoot.resolve('notification_event_type.dart')}';
void main() {
  const factory = HashNotificationIdFactory();
  print(jsonEncode([
    factory.create(const NotificationKey(type: NotificationEventType.tempTarget, entityId: 13)),
    factory.create(const NotificationKey(type: NotificationEventType.eatNow, entityId: 42)),
    factory.create(const NotificationKey(type: NotificationEventType.activityFinished, entityId: 7)),
  ]));
}
''');
      for (var run = 0; run < 2; run++) {
        final result = await Process.run('dart', [
          'run',
          script.path,
        ], runInShell: Platform.isWindows).timeout(const Duration(seconds: 20));
        expect(result.exitCode, 0, reason: result.stderr.toString());
        expect(jsonDecode(result.stdout.toString().trim()), expectedIds);
      }
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
