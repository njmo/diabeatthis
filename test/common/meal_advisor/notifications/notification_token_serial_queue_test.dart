import 'dart:async';

import 'package:diabeatthis/common/meal_advisor/notifications/notification_token_serial_queue.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deletion finishes before the next account can register', () async {
    final queue = NotificationTokenSerialQueue();
    final gate = Completer<void>();
    final actions = <String>[];
    final first = queue.run(
      deleteToken: () async {},
      operation: () async {
        actions.add('old registration');
        await gate.future;
      },
    );
    await Future<void>.delayed(Duration.zero);
    queue.invalidate();
    final second = queue.run(
      deleteToken: () async {
        actions.add('delete token');
      },
      operation: () async {
        actions.add('new registration');
      },
    );
    expect(actions, ['old registration']);
    gate.complete();
    await Future.wait([first, second]);
    expect(actions, ['old registration', 'delete token', 'new registration']);
  });

  test('failed token deletion stays pending until it succeeds', () async {
    final queue = NotificationTokenSerialQueue();
    var registrations = 0;
    queue.invalidate();
    await expectLater(
      queue.run(
        deleteToken: () async => throw StateError('failed'),
        operation: () async {
          registrations++;
        },
      ),
      throwsStateError,
    );
    await queue.run(
      deleteToken: () async {},
      operation: () async {
        registrations++;
      },
    );
    expect(registrations, 1);
  });
}
