import 'dart:async';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/family_chat_test_api.dart';

class _RacingApi extends FamilyChatTestApi {
  _RacingApi() : super('child');
  final entered = Completer<void>();
  final release = Completer<void>();
  final attempts = <Map<String, Object?>>[];

  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (name == 'sendFamilyChatMessage') {
      if (allowRequest != null && !await allowRequest()) {
        throw const CallableFailure('cancelled');
      }
      attempts.add(Map.of(data));
      if (attempts.length == 1) {
        entered.complete();
        await release.future;
      } else {
        throw const CallableFailure('rejected', rejectionCode: 'not-found');
      }
    }
    return super.call(name, data, allowRequest: allowRequest);
  }
}

void main() {
  test(
    'a later signed rejection cannot reticket an earlier held send',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = _RacingApi();
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(() async {
        if (!api.release.isCompleted) api.release.complete();
        session.dispose();
        await db.close();
      });
      await session.start();
      final scope = session.scope!;
      final now = session.serverNow;
      final operation = await db.enqueue(scope, 'mom', {
        'kind': 'text',
        'text': 'One message',
        'answers': <String>[],
      }, now);
      expect(operation, isNotNull);
      // A previous worker's POST is still in flight after losing its response.
      final row = (await db.outbox(scope)).single;
      final held = api.call('sendFamilyChatMessage', {
        'ticket': row.read<String>('id'),
        'targetUid': 'mom',
        'kind': 'text',
        'text': 'One message',
        'answers': <String>[],
      });
      await api.entered.future;
      await session.synchronize();
      expect(session.messages('mom').single['sendOutcomeUnknown'], true);
      final attempts = api.attempts.length;
      await expectLater(session.retry('mom', operation!), throwsStateError);
      expect(api.attempts, hasLength(attempts));
      expect((await db.outbox(scope)).single.read<String>('id'), operation);
      api.release.complete();
      await held;
      await session.synchronize();
      expect(api.messages, hasLength(1));
      expect(await db.outbox(scope), isEmpty);
      expect(api.attempts.map((data) => data['ticket']).toSet(), {operation});
    },
  );
}
