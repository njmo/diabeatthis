import 'dart:async';

import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/presentation/family_chat_conversation.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/family_chat_test_api.dart';

/// The conversation closes an ordinary question through the shared reply
/// policy instead of any row that happens to carry `replyTo`.
void main() {
  const childScope = '["child","f","e"]';

  Map<String, dynamic> questionRow(int now) => {
    'id': 'q',
    'kind': 'question',
    'text': 'Masz wodę?',
    'senderUid': 'mom',
    'answers': ['Mam', 'Kupię'],
    'sequence': 1,
    'sentAt': now,
    'expiresAt': now + 86400000,
    'receipts': {
      'child': {'deliveredAt': now, 'readAt': null},
    },
  };

  Map<String, dynamic> answerRow(int now, String sender) => {
    'id': 'a-$sender',
    'kind': 'answer',
    'replyTo': 'q',
    'answerIndex': 0,
    'text': 'Mam',
    'senderUid': sender,
    'answers': <String>[],
    'sequence': 2,
    'sentAt': now + 1,
    'expiresAt': now + 86400000,
    'receipts': <String, dynamic>{},
  };

  Future<FamilyChatSession> start(
    WidgetTester tester,
    FamilyChatTestApi api,
    FamilyChatDatabase db, {
    required bool caregiver,
  }) async {
    final session = FamilyChatSession(
      uid: api.uid,
      api: api,
      db: db,
      isCurrentAccount: () => true,
    );
    // Same lifecycle as the conversation test fixture.
    addTearDown(() async {
      session.dispose();
      await db.close();
    });
    await session.start();
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ListenableBuilder(
          listenable: session,
          builder: (_, _) => FamilyChatConversation(
            isCaregiver: caregiver,
            session: session,
            initialTarget: 'mom',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  Future<void> seedOwnAnswer(
    WidgetTester tester,
    FamilyChatDatabase db,
    int now, {
    required String? error,
  }) async {
    await db.addTickets(childScope, [
      {'id': 'op', 'token': 'signed', 'expiresAt': now + 86400000},
    ]);
    final id = await db.enqueue(childScope, 'mom', {
      'kind': 'answer',
      'text': 'Kupię',
      'answers': <String>[],
      'answerIndex': 1,
      'replyTo': 'q',
    }, now);
    if (error != null) await db.failOperation(childScope, id!, error);
  }

  Finder choice(String text) => find.widgetWithText(OutlinedButton, text);

  testWidgets('a caregiver reply does not answer the child question', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final api = FamilyChatTestApi('child')
      ..additionalMembers.add({
        'uid': 'dad',
        'role': 'managingCaregiver',
        'displayName': 'Tata',
      })
      ..messages.addAll([questionRow(now), answerRow(now, 'dad')]);
    await start(
      tester,
      api,
      FamilyChatDatabase(NativeDatabase.memory()),
      caregiver: false,
    );
    // The foreign answer stays visible verbatim, the child can still answer.
    expect(find.text('Mam'), findsWidgets);
    expect(choice('Mam'), findsOneWidget);
    expect(choice('Kupię'), findsOneWidget);
  });

  for (final caregiver in [false, true]) {
    testWidgets('a confirmed child answer closes the question: $caregiver', (
      tester,
    ) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final uid = caregiver ? 'parent' : 'child';
      final api = FamilyChatTestApi(uid, caregiver: caregiver);
      api.messages.addAll([
        {...questionRow(now), 'senderUid': caregiver ? uid : 'mom'},
        answerRow(now, caregiver ? 'mom' : uid),
      ]);
      await start(
        tester,
        api,
        FamilyChatDatabase(NativeDatabase.memory()),
        caregiver: caregiver,
      );
      expect(choice('Kupię'), findsNothing);
      expect(find.widgetWithText(Chip, 'Kupię'), findsNothing);
    });
  }

  // Requires the Session D projection ('operationError'/'operationSigned');
  // the legacy delivery flag cannot tell signed rejections from unsent ones.
  testWidgets('a signed rejected own answer still blocks a new choice', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = FamilyChatDatabase(NativeDatabase.memory());
    await seedOwnAnswer(tester, db, now, error: 'not-found');
    final api = FamilyChatTestApi('child')..messages.add(questionRow(now));
    await start(tester, api, db, caregiver: false);
    expect(find.text('Kupię'), findsWidgets);
    expect(choice('Mam'), findsNothing);
    // Ambiguous, so no resend is offered either.
    expect(find.textContaining('Ponów'), findsNothing);
    expect(api.sendRequests, 0);
  });

  // Requires the Session D projection. Seeded before mount, so this covers the
  // policy and a double tap only, not the in-flight guard reset (see below).
  testWidgets(
    'a known unsent failure reopens; tapping another choice sends once',
    (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = FamilyChatDatabase(NativeDatabase.memory());
      await db.enqueueUnsentReply(
        childScope,
        'unsent_old',
        'mom',
        {
          'kind': 'answer',
          'text': 'Kupię',
          'answers': <String>[],
          'answerIndex': 1,
          'replyTo': 'q',
        },
        now,
        'notificationReply:$childScope:q',
      );
      await db.failOperation(childScope, 'unsent_old', 'expired');
      final api = FamilyChatTestApi('child')..messages.add(questionRow(now));
      await start(tester, api, db, caregiver: false);
      // The failed bubble stays visible; a conscious new choice is possible.
      expect(find.text('Kupię'), findsWidgets);
      expect(choice('Mam'), findsOneWidget);
      // Rapid double tap: the in-flight guard and the pending row allow one.
      await tester.tap(choice('Mam'));
      await tester.tap(choice('Mam'), warnIfMissed: false);
      await tester.pump();
      await tester.pumpAndSettle();
      expect(api.sendRequests, 1);
      expect(api.sendPayloads.single['text'], 'Mam');
      expect(api.sendPayloads.single['replyTo'], 'q');
      expect(api.sendPayloads.single['answerIndex'], 0);
      expect(choice('Mam'), findsNothing);
      expect(choice('Kupię'), findsNothing);
    },
  );

  // Same-widget regression for the in-flight guard. Requires the Session D
  // projection ('operationSigned') so the unsigned failure reopens.
  testWidgets(
    'same widget: unsigned offline answer fails, then another choice sends',
    (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child')..messages.add(questionRow(now));
      final session = await start(tester, api, db, caregiver: false);
      Future<void> sync() async {
        try {
          await session.synchronize();
        } catch (_) {}
        await tester.pump();
      }

      api.offlineConfig = true;
      await sync();
      await tester.tap(choice('Mam'));
      await tester.pump();
      await tester.pump();
      final queued = await db.outbox(childScope);
      expect(queued, hasLength(1));
      final payload = queued.single.read<String>('payload');
      // Offline, so the answer was queued without a ticket (never sent).
      expect(payload, isNot(contains('"ticket"')));
      expect(payload, contains('"replyTo":"q"'));
      expect(choice('Mam'), findsNothing);
      expect(api.sendRequests, 0);

      await db.failOperation(
        childScope,
        queued.single.read<String>('id'),
        'expired',
      );
      api.offlineConfig = false;
      await sync();
      await tester.pumpAndSettle();
      // Known unsent failure: the question reopens in the SAME widget and
      // the earlier tap's in-flight guard no longer swallows a new tap.
      expect(choice('Kupię'), findsOneWidget);
      await tester.tap(choice('Kupię'));
      await tester.pumpAndSettle();
      expect(api.sendRequests, 1);
      expect(api.sendPayloads.single['text'], 'Kupię');
      expect(api.sendPayloads.single['replyTo'], 'q');
      expect(api.sendPayloads.single['answerIndex'], 1);
      expect(choice('Kupię'), findsNothing);
    },
  );

  testWidgets('an ambiguous own answer blocks a new choice across restart', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = FamilyChatDatabase(NativeDatabase.memory());
    await seedOwnAnswer(tester, db, now, error: 'send-outcome-unknown');
    final api = FamilyChatTestApi('child')..messages.add(questionRow(now));
    await start(tester, api, db, caregiver: false);
    expect(choice('Mam'), findsNothing);
    expect(api.sendRequests, 0);
  });

  testWidgets('a pending own answer blocks duplicates while sending', (
    tester,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final db = FamilyChatDatabase(NativeDatabase.memory());
    final api = FamilyChatTestApi('child')..messages.add(questionRow(now));
    // Start unblocked; only the later in-widget send is held.
    await start(tester, api, db, caregiver: false);
    final gate = api.sendGate = Completer<void>();
    await tester.tap(choice('Mam'));
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));
    expect(choice('Mam'), findsNothing);
    expect(choice('Kupię'), findsNothing);
    gate.complete();
    await tester.pumpAndSettle();
    expect(api.sendRequests, 1);
    expect(choice('Mam'), findsNothing);
  });

  testWidgets(
    'a legacy redacted marker blocks earlier questions of its target',
    (tester) async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final db = FamilyChatDatabase(NativeDatabase.memory());
      await db.setMetadata('outcome:$childScope:legacy', {
        'id': 'legacy',
        'state': 'unknown',
        'target': 'mom',
        'createdAt': now + 5,
      });
      final api = FamilyChatTestApi('child')..messages.add(questionRow(now));
      await start(tester, api, db, caregiver: false);
      expect(choice('Mam'), findsNothing);
      expect(api.sendRequests, 0);
    },
  );
}
