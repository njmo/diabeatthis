import 'dart:convert';

import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// The DB reply gate (notification suppression and background replies) uses
/// the shared domain reply policy.
void main() {
  const scope = 's';
  const day = 86400000;
  late FamilyChatDatabase db;

  setUp(() {
    db = FamilyChatDatabase(NativeDatabase.memory());
    addTearDown(db.close);
  });

  Future<void> question(String id, {String target = 'mom', int sentAt = 10}) =>
      db.saveMessage(scope, target, {
        'id': id,
        'kind': 'question',
        'text': 'Masz wodę?',
        'answers': ['Mam'],
        'senderUid': 'mom',
        'sentAt': sentAt,
        'receipts': <String, dynamic>{},
      });

  Future<String> signedAnswer(String parent, {String token = 't'}) async {
    await db.addTickets(scope, [
      {'id': 'op-${parent.length}', 'token': token, 'expiresAt': 9000},
    ]);
    return (await db.enqueue(scope, 'mom', {
      'kind': 'answer',
      'text': 'Mam',
      'answers': <String>[],
      'replyTo': parent,
    }, 100))!;
  }

  test(
    'pending and every signed terminal reply block; only unsent failure reopens',
    () async {
      await question('q');
      expect(await db.hasAuthoredReply(scope, 'child', 'q'), false);
      final id = await signedAnswer('q');
      expect(await db.hasAuthoredReply(scope, 'child', 'q'), true);
      for (final ambiguous in [
        'send-outcome-unknown',
        'expired',
        'already-exists',
        'cancelled',
        'internal',
        'failed-precondition',
      ]) {
        await db.failOperation(scope, id, ambiguous);
        expect(
          await db.hasAuthoredReply(scope, 'child', 'q'),
          true,
          reason: ambiguous,
        );
      }
      // A rejection never proves an earlier same-ID request did not commit.
      for (final rejection in [
        'not-found',
        'invalid-argument',
        'permission-denied',
      ]) {
        await db.failOperation(scope, id, rejection);
        expect(
          await db.hasAuthoredReply(scope, 'child', 'q'),
          true,
          reason: rejection,
        );
      }
      // The row itself is preserved for the user to see.
      expect(await db.outbox(scope), hasLength(1));
    },
  );

  test('an unsigned reply is never ambiguous once it stops waiting', () async {
    await question('q');
    await db.enqueueUnsentReply(
      scope,
      'unsent',
      'mom',
      {'kind': 'answer', 'text': 'Mam', 'replyTo': 'q'},
      100,
      'notificationReply:$scope:q',
    );
    expect(await db.hasAuthoredReply(scope, 'child', 'q'), true);
    await db.failOperation(scope, 'unsent', 'expired');
    expect(await db.hasAuthoredReply(scope, 'child', 'q'), false);
  });

  test(
    'only the account\'s own answers count; empty uid never authorizes',
    () async {
      await question('q');
      await db.saveMessage(scope, 'mom', {
        'id': 'foreign',
        'kind': 'answer',
        'text': 'Mam',
        'replyTo': 'q',
        'senderUid': 'dad',
        'sentAt': 20,
        'receipts': <String, dynamic>{},
      });
      expect(await db.hasAuthoredReply(scope, 'child', 'q'), false);
      expect(await db.hasAuthoredReply(scope, '', 'q'), true);
      await db.saveMessage(scope, 'mom', {
        'id': 'own',
        'kind': 'answer',
        'text': 'Mam',
        'replyTo': 'q',
        'senderUid': 'child',
        'sentAt': 21,
        'receipts': <String, dynamic>{},
      });
      expect(await db.hasAuthoredReply(scope, 'child', 'q'), true);
    },
  );

  test(
    'purged answers keep only kind and replyTo in their outcome marker',
    () async {
      await db.applyRetention(scope, {'revision': 1, 'retention': 'day'});
      await question('q');
      await question('other');
      await signedAnswer('q', token: 'secret-ticket');
      await db.purge(scope, day + 200);
      expect(await db.outbox(scope), isEmpty);
      final markers = await db.outcomeMarkers(scope);
      expect(markers, hasLength(1));
      expect(markers.single['kind'], 'answer');
      expect(markers.single['replyTo'], 'q');
      expect(markers.single['state'], 'unknown');
      final encoded = jsonEncode(markers);
      expect(encoded, isNot(contains('Mam')));
      expect(encoded, isNot(contains('secret-ticket')));
      expect(await db.hasAuthoredReply(scope, 'child', 'q'), true);
      expect(await db.hasAuthoredReply(scope, 'child', 'other'), false);
    },
  );

  test(
    'legacy markers block only earlier questions of the same target',
    () async {
      await question('before', sentAt: 10);
      await question('after', sentAt: 500);
      await question('elsewhere', target: 'dad', sentAt: 10);
      await db.setMetadata('outcome:$scope:legacy', {
        'id': 'legacy',
        'state': 'unknown',
        'target': 'mom',
        'createdAt': 100,
      });
      expect(await db.hasAuthoredReply(scope, 'child', 'before'), true);
      expect(await db.hasAuthoredReply(scope, 'child', 'after'), false);
      expect(await db.hasAuthoredReply(scope, 'child', 'elsewhere'), false);
    },
  );

  test('associated markers for other kinds never block questions', () async {
    await question('q');
    await db.setMetadata('outcome:$scope:text', {
      'id': 'text',
      'state': 'unknown',
      'target': 'mom',
      'createdAt': 100,
      'kind': 'text',
      'replyTo': null,
    });
    expect(await db.hasAuthoredReply(scope, 'child', 'q'), false);
  });
}
