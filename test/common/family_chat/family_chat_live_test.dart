import 'dart:async';
import 'dart:io';

import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_runtime.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/presentation/family_chat_conversation.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/family_chat_test_api.dart';

class _ClearGate extends FamilyChatDatabase {
  _ClearGate() : super(NativeDatabase.memory());
  final entered = Completer<void>();
  final release = Completer<void>();
  bool held = false;
  @override
  Future<void> clearAccount(String uid, {bool preserveHistory = false}) async {
    if (held) {
      entered.complete();
      await release.future;
      held = false;
    }
    await super.clearAccount(uid, preserveHistory: preserveHistory);
  }
}

class _HandoffDb extends FamilyChatDatabase {
  _HandoffDb() : super(NativeDatabase.memory());
  bool holdNextOutbox = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<List<QueryRow>> outbox(String scope) async {
    final rows = await super.outbox(scope);
    if (holdNextOutbox) {
      holdNextOutbox = false;
      entered.complete();
      await release.future;
    }
    return rows;
  }
}

class _DraftGateDb extends FamilyChatDatabase {
  _DraftGateDb() : super(NativeDatabase.memory());
  bool holdNextDraft = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> saveDraft(
    String scope,
    String target,
    String value, {
    int? serverNow,
    FamilyChatDraftEdit? edit,
    bool allowCreate = true,
  }) async {
    if (holdNextDraft) {
      holdNextDraft = false;
      entered.complete();
      await release.future;
    }
    await super.saveDraft(
      scope,
      target,
      value,
      serverNow: serverNow,
      edit: edit,
      allowCreate: allowCreate,
    );
  }
}

class _ShortcutReadGateDb extends FamilyChatDatabase {
  _ShortcutReadGateDb() : super(NativeDatabase.memory());
  bool hold = false;
  final entered = Completer<void>();
  final release = Completer<void>();
  @override
  Future<Map<String, dynamic>?> metadata(String key) async {
    final value = await super.metadata(key);
    if (hold && key.startsWith('shortcutEdit:')) {
      hold = false;
      entered.complete();
      await release.future;
    }
    return value;
  }
}

Future<void> _pumpSync(WidgetTester tester, FamilyChatSession session) async {
  var complete = false;
  final sync = session.synchronize()..then((_) => complete = true);
  for (var count = 0; count < 600 && !complete; count++) {
    await tester.pump(const Duration(milliseconds: 10));
  }
  expect(complete, true);
  await sync;
}

void main() {
  test(
    'conversation summaries reject foreign and stale responses, including after OFF',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child')
        ..unreadByTarget = {'family': true, 'mom': false};
      final session = FamilyChatSession(
        uid: api.uid,
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      expect(session.hasUnreadIn('family'), isTrue);
      expect(session.hasUnreadIn('mom'), isFalse);
      api.unreadByTarget!['family'] = false;
      for (final override in [
        {'uid': 'other'},
        {'familyId': 'other'},
        {'epoch': 'old'},
        {'historyGeneration': -1},
        {'serverTime': 1},
      ]) {
        api.conversationSummaryOverrides
          ..clear()
          ..addAll(override);
        await session.synchronize();
        expect(session.hasUnreadIn('family'), isTrue, reason: '$override');
      }
      api.conversationSummaryOverrides.clear();
      await session.synchronize();
      expect(session.hasUnreadIn('family'), isFalse);

      api
        ..heldOperation = 'fetchFamilyChatConversations'
        ..operationEntered = Completer<void>()
        ..operationRelease = Completer<void>();
      api.unreadByTarget!['family'] = true;
      final sync = session.synchronize();
      await api.operationEntered!.future;
      session.suspendIdentity();
      api.operationRelease!.complete();
      await sync;
      expect(session.hasUnreadIn('family'), isNull);
      api.accountEnabled = false;
      await session.synchronize();
      expect(session.hasUnreadIn('family'), isNull);
    },
  );

  for (final networkChanged in [true, false]) {
    test(
      'Home reconnect retries exhausted queue: networkChanged=$networkChanged',
      () {
        fakeAsync((time) {
          final db = FamilyChatDatabase(NativeDatabase.memory());
          final api = FamilyChatTestApi('parent', caregiver: true);
          final runtime = FamilyChatRuntime(db);
          unawaited(runtime.update('parent', true, api));
          time.flushMicrotasks();
          expect(runtime.session, isNotNull);
          if (!networkChanged) runtime.setNetworkConnected(true);
          api.offlineConfig = true;
          unawaited(runtime.session!.send('mom', 'Reconnect from Home'));
          time.flushMicrotasks();
          time.elapse(const Duration(minutes: 3));
          final exhausted = api.configCalls;
          time.elapse(const Duration(minutes: 10));
          expect(api.configCalls, exhausted);
          expect(api.sendRequests, 0);
          api.offlineConfig = false;
          if (networkChanged) {
            runtime.setNetworkConnected(true);
          } else {
            runtime.setBackendVerified(true);
          }
          time.flushMicrotasks();
          expect(api.sendRequests, 1);
          expect(api.sendPayloads.single['text'], 'Reconnect from Home');
          final sentCount = api.configCalls;
          time.elapse(const Duration(minutes: 2));
          expect(api.configCalls, sentCount);
          runtime.dispose();
          unawaited(db.close());
          time.flushMicrotasks();
        });
      },
    );
  }
  testWidgets(
    'cached offline composer accepts text and questions into durable pending bubbles',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('parent', caregiver: true);
      FamilyChatSession create() => FamilyChatSession(
        uid: 'parent',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      final first = create();
      await first.start();
      first.dispose();
      api.offlineConfig = true;
      await db.fence.block();
      final session = create();
      await session.start();
      final calls = api.configCalls;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ListenableBuilder(
            listenable: session,
            builder: (_, _) =>
                FamilyChatConversation(isCaregiver: true, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Tekst offline');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij wiadomość'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Tekst offline'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'Pytanie offline');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij pytanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Wyślij pytanie'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        isEmpty,
      );
      expect(find.text('Pytanie offline'), findsOneWidget);
      expect((await db.outbox(session.scope!)).length, 2);
      expect(api.sendRequests, 0);
      expect(api.configCalls, calls);
      api.offlineConfig = false;
      await _pumpSync(tester, session);
      await tester.pumpAndSettle();
      expect(api.sendRequests, 2);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'answer card is read only when its own text enters the viewport',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('parent', caregiver: true);
      api.additionalMembers.add({
        'uid': 'dad',
        'role': 'managingCaregiver',
        'displayName': 'Tata',
      });
      final now = DateTime.now().millisecondsSinceEpoch;
      api.messages.addAll([
        {
          'id': 'long-question',
          'kind': 'question',
          'conversationId': 'family',
          'text': List.filled(60, 'Długie pytanie').join('\n'),
          'senderUid': 'mom',
          'answers': ['Tak'],
          'sequence': 1,
          'sentAt': now,
          'expiresAt': now + 86400000,
          'receipts': {
            'parent': {'deliveredAt': null, 'readAt': null},
          },
        },
        {
          'id': 'inline-answer',
          'kind': 'answer',
          'conversationId': 'family',
          'replyTo': 'long-question',
          'text': 'Tak',
          'senderUid': 'dad',
          'answers': <String>[],
          'sequence': 2,
          'sentAt': now + 1,
          'expiresAt': now + 86400000,
          'receipts': {
            'parent': {'deliveredAt': null, 'readAt': null},
          },
        },
      ]);
      final session = FamilyChatSession(
        uid: 'parent',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      Widget app() => MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ListenableBuilder(
          listenable: session,
          builder: (_, _) => FamilyChatConversation(
            isCaregiver: true,
            session: session,
            initialTarget: 'family',
          ),
        ),
      );
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      final list = tester.widget<ListView>(find.byType(ListView));
      list.controller!.jumpTo(list.controller!.position.maxScrollExtent);
      await tester.pumpAndSettle();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpWidget(app());
      await tester.pumpAndSettle();
      await _pumpSync(tester, session);
      expect(api.readIds, contains('long-question'));
      expect(api.readIds, isNot(contains('inline-answer')));
      list.controller!.jumpTo(list.controller!.position.minScrollExtent);
      await tester.pumpAndSettle();
      await _pumpSync(tester, session);
      expect(api.readIds, contains('inline-answer'));
      expect(find.text('Tata'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
    },
  );
  for (final caregiver in [false, true]) {
    testWidgets(
      'question and selected answer use separate marked cards: caregiver=$caregiver',
      (tester) async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final uid = caregiver ? 'parent' : 'child';
        final api = FamilyChatTestApi(uid, caregiver: caregiver);
        final now = DateTime.now().millisecondsSinceEpoch;
        api.messages.addAll([
          {
            'id': 'q',
            'kind': 'question',
            'text': 'Masz śniadanie?',
            'senderUid': caregiver ? uid : 'mom',
            'answers': ['Mam', 'Nie mam'],
            'sequence': 1,
            'sentAt': now,
            'expiresAt': now + 86400000,
            'receipts': <String, dynamic>{},
          },
          {
            'id': 'a',
            'answerIndex': 0,
            'kind': 'answer',
            'replyTo': 'q',
            'text': 'Mam',
            'senderUid': caregiver ? 'mom' : uid,
            'answers': <String>[],
            'sequence': 2,
            'sentAt': now + 1,
            'expiresAt': now + 86400000,
            'receipts': <String, dynamic>{},
          },
        ]);
        final session = FamilyChatSession(
          uid: uid,
          api: api,
          db: db,
          isCurrentAccount: () => true,
        );
        await session.start();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FamilyChatConversation(
              isCaregiver: caregiver,
              session: session,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Masz śniadanie?'), findsOneWidget);
        expect(find.text('Mam'), findsOneWidget);
        expect(find.text('Nie mam'), findsNothing);
        expect(find.widgetWithText(OutlinedButton, 'Mam'), findsNothing);
        expect(find.text('Selected reply'), findsOneWidget);
        expect(find.byIcon(Icons.help_outline_rounded), findsWidgets);
        expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        await db.close();
      },
    );
  }
  testWidgets(
    'parent send arrow sends text directly and canceled question does not consume the draft',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('parent', caregiver: true);
      final session = FamilyChatSession(
        uid: 'parent',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: true, session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Zwykły tekst');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij pytanie'));
      await tester.pumpAndSettle();
      expect(api.sendRequests, 0);
      await tester.tap(find.byTooltip('Zamknij formularz'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Zwykły tekst',
      );
      await tester.tap(find.byTooltip('Wyślij wiadomość'));
      await tester.pumpAndSettle();
      expect(find.text('Zapytaj dziecko'), findsNothing);
      expect(api.sendPayloads.single['kind'], 'text');
      expect(api.sendPayloads.single['text'], 'Zwykły tekst');
      expect(api.sendPayloads.single['answers'], isEmpty);
      expect(await db.draft(session.scope!, 'mom'), '');
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'parent question button opens the spaced form and sends exactly one chosen reply',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('parent', caregiver: true);
      final session = FamilyChatSession(
        uid: 'parent',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: true, session: session),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Masz wodę?');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij pytanie'));
      await tester.pumpAndSettle();
      final question = find.byWidgetPredicate(
        (widget) =>
            widget is TextField &&
            widget.decoration?.labelText == 'Treść pytania',
      );
      expect(
        tester.getTopLeft(question).dy -
            tester
                .getBottomLeft(
                  find.text('Dodaj pytanie i opcjonalne odpowiedzi.'),
                )
                .dy,
        greaterThanOrEqualTo(12),
      );
      expect(api.sendRequests, 0);
      await tester.tap(find.byTooltip('Dodaj odpowiedź'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Odpowiedź 1',
        ),
        'Tak',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Wyślij pytanie'));
      await tester.pumpAndSettle();
      expect(api.sendPayloads.single['kind'], 'question');
      expect(api.sendPayloads.single['text'], 'Masz wodę?');
      expect(api.sendPayloads.single['answers'], ['Tak']);
      expect(await db.draft(session.scope!, 'mom'), '');
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'expired open composer clears and closing cannot restore its old body',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final session = FamilyChatSession(
        uid: 'child',
        api: FamilyChatTestApi('child'),
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ListenableBuilder(
            listenable: session,
            builder: (context, _) =>
                FamilyChatConversation(isCaregiver: false, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, 'Private draft');
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      final target = session.targets.firstWhere(
        (target) => session.draft(target).isNotEmpty,
      );
      expect(await db.draft(session.scope!, target), 'Private draft');
      await db.purge(session.scope!, session.serverNow + 8 * 86400000);
      await session.synchronize();
      await tester.pumpAndSettle();
      expect(find.text('Private draft'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(await db.draft(session.scope!, target), '');
      session.dispose();
      await db.close();
    },
  );
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'redacted unknown status survives real SQLite reopen without retaining its body or retrying a send',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'chat-outcome-restart-',
      );
      final file = File('${directory.path}/chat.sqlite');
      var db = FamilyChatDatabase(NativeDatabase(file));
      FamilyChatSession? session;
      addTearDown(() async {
        session?.dispose();
        await db.close();
        await directory.delete(recursive: true);
      });
      const scope = '["child","f","e"]';
      await db.addTickets(scope, [
        {'id': 'old-operation', 'token': 'old-ticket', 'expiresAt': 100},
      ]);
      await db.enqueue(scope, 'mom', {
        'text': 'PRIVATE ORIGINAL BODY',
        'kind': 'text',
      }, 10);
      await db.failOperation(
        scope,
        'old-operation',
        'expired',
      ); // Legacy database.
      await db.purge(scope, 604800101);
      await db.close();
      db = FamilyChatDatabase(NativeDatabase(file));
      final api = FamilyChatTestApi('child');
      final current = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      session = current;
      await current.start();
      expect(current.messages('mom').single['redactedOutcome'], true);
      expect(
        current.messages('mom').single['text'],
        isNot(contains('PRIVATE ORIGINAL BODY')),
      );
      await current.verifyOutcome('mom', 'old-operation');
      expect(api.sendRequests, 0);
      expect(
        (await current.db.metadata(
          'outcome:["child","f","e"]:old-operation',
        ))?['state'],
        'unknown',
      );
      await current.discardOutcome('mom', 'old-operation');
      expect(current.messages('mom'), isEmpty);
      expect(
        await current.db.metadata('outcome:["child","f","e"]:old-operation'),
        isNull,
      );
      await current.synchronize();
    },
  );
  testWidgets(
    'redacted unknown marker offers read-only status verification and local discard without resend',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      const scope = '["child","f","e"]';
      await db.setMetadata('outcome:$scope:old-operation', {
        'id': 'old-operation',
        'state': 'unknown',
        'target': 'mom',
        'createdAt': DateTime.now().millisecondsSinceEpoch,
      });
      final api = FamilyChatTestApi('child');
      final current = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await current.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ListenableBuilder(
            listenable: current,
            builder: (context, _) => FamilyChatConversation(
              isCaregiver: false,
              session: current,
              initialTarget: 'mom',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text('Treść wiadomości została usunięta z tego urządzenia.'),
        findsOneWidget,
      );
      expect(find.text('Sprawdź status'), findsOneWidget);
      expect(find.text('Ponów wysyłanie'), findsNothing);
      await tester.tap(find.text('Usuń lokalny status'));
      await _pumpSync(tester, current);
      await tester.pumpAndSettle();
      expect(
        find.text('Treść wiadomości została usunięta z tego urządzenia.'),
        findsNothing,
      );
      expect(api.sendRequests, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      await current.synchronize();
      current.dispose();
      await db.close();
    },
  );
  test(
    'an unknown send does not suspend other messages and verification reuses only its original ticket',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      api.rejectSendReason = 'chat-send-outcome-unknown';
      await session.send('mom', 'Uncertain');
      await session.synchronize();
      expect(session.enabled, true);
      final uncertain = session.messages('mom').single;
      expect(uncertain['sendOutcomeUnknown'], true);
      final originalTicket = api.sendPayloads.single['ticket'];
      api.rejectSendReason = null;
      await session.send('mom', 'A different message');
      await session.synchronize();
      expect(api.messages, hasLength(1));
      await expectLater(
        session.retry('mom', uncertain['id'] as String),
        throwsStateError,
      );
      await session.verifyOutcome('mom', uncertain['id'] as String);
      expect(api.sendPayloads.last['verifyOnly'], true);
      expect(api.sendPayloads.last['ticket'], originalTicket);
      expect(api.messages, hasLength(1));
      expect(
        session
            .messages('mom')
            .where((message) => message['sendOutcomeUnknown'] == true),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'unknown delivery offers status verification instead of a new send',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      api.rejectSendReason = 'chat-send-outcome-unknown';
      await session.send('mom', 'Uncertain');
      await _pumpSync(tester, session);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(
            isCaregiver: false,
            session: session,
            initialTarget: 'mom',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Nie udało się potwierdzić wysłania.'), findsOneWidget);
      expect(find.text('Sprawdź status'), findsOneWidget);
      expect(find.text('Ponów wysyłanie'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      session.dispose();
      await db.close();
    },
  );
  for (final operation in [
    'fetchFamilyChatConversations',
    'fetchFamilyChatMessages',
    'fetchFamilyChatMessageStates',
    'reserveFamilyChatOperations',
    'fetchFamilyChatShortcuts',
    'sendFamilyChatMessage',
    'loadHistory',
  ]) {
    test(
      'late $operation response cannot recreate cache after completed OFF purge',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final api = FamilyChatTestApi('child');
        api.messages.add({
          'id': 'old-message',
          'senderUid': 'mom',
          'sequence': 1,
          'sentAt': DateTime.now().millisecondsSinceEpoch,
          'expiresAt': DateTime.now().millisecondsSinceEpoch + 86400000,
          'text': 'Private body',
          'kind': 'text',
          'receipts': {
            'child': {'deliveredAt': null, 'readAt': null},
          },
        });
        final session = FamilyChatSession(
          uid: 'child',
          api: api,
          db: db,
          isCurrentAccount: () => true,
        );
        addTearDown(session.dispose);
        await session.start();
        final scope = session.scope!;
        if (operation == 'reserveFamilyChatOperations') {
          await db.invalidateTickets(scope);
        }
        api.heldOperation = operation == 'loadHistory'
            ? 'fetchFamilyChatMessages'
            : operation;
        api.operationEntered = Completer<void>();
        api.operationRelease = Completer<void>();
        Future<void> pending;
        if (operation == 'loadHistory') {
          // loadHistory surfaces errors to its caller; the OFF latch must
          // refuse the held request after identity. Attach the expectation
          // before release so the refusal is asserted, not leaked.
          pending = session
              .loadHistory('mom', latest: true)
              .then<void>(
                (_) => fail('held loadHistory must be refused after OFF'),
                onError: (Object error) => expect(
                  error,
                  isA<CallableFailure>().having(
                    (failure) => failure.code,
                    'code',
                    'cancelled',
                  ),
                ),
              );
        } else if (operation == 'sendFamilyChatMessage') {
          await session.send('mom', 'Pending send');
          pending = session.synchronize();
        } else {
          pending = session.synchronize();
        }
        await api.operationEntered!.future.timeout(const Duration(seconds: 3));
        await db.fence.revokeAccount('child');
        await db.clearAccount('child');
        api.operationRelease!.complete();
        await pending;
        expect(await db.messages(scope, 'mom'), isEmpty);
        expect(await db.receipts(scope), isEmpty);
        expect(await db.outbox(scope), isEmpty);
        expect(
          await db.validTicketCount(
            scope,
            DateTime.now().millisecondsSinceEpoch,
          ),
          0,
        );
        for (final key in [
          'threads:$scope',
          'cursor:$scope:mom',
          'shortcuts:$scope',
          'account:child',
        ]) {
          expect(await db.metadata(key), isNull, reason: key);
        }
      },
    );
  }
  test(
    'cold cached history cannot use stored tickets or write receipts and shortcuts',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      FamilyChatSession create() => FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      final first = create();
      await first.start();
      expect(first.serverVerified, true);
      final scope = first.scope!;
      first.dispose();
      api.offlineConfig = true;
      await db.fence.block();
      final cached = create();
      addTearDown(cached.dispose);
      await cached.start();
      expect(cached.enabled, true);
      expect(cached.serverVerified, false);
      await cached.saveDraft('mom', 'Private offline draft');
      expect(await db.draft(scope, 'mom'), 'Private offline draft');
      final before = (await db.outbox(scope)).length;
      await cached.send('mom', 'Queued offline');
      await cached.send('mom', 'Answer', kind: 'answer', replyTo: 'question');
      expect((await db.outbox(scope)).length, before + 2);
      expect(
        cached
            .messages('mom')
            .where((message) => message['delivery'] == 'pending')
            .length,
        2,
      );
      await expectLater(
        cached.saveShortcuts([
          {'id': 'a', 'text': 'No'},
        ]),
        throwsStateError,
      );
      expect(await cached.markRead('mom'), false);
      await cached.retry('mom', 'pending');
      expect((await db.outbox(scope)).length, before + 2);
      expect(await db.metadata('shortcutEdit:$scope'), isNull);
      expect(api.sendRequests, 0);
      api.offlineConfig = false;
      await cached.synchronize();
      expect(cached.serverVerified, true);
      cached.suspendIdentity();
      expect(cached.serverVerified, false);
      await expectLater(cached.send('mom', 'Suspended'), throwsStateError);
    },
  );

  test(
    'independent OFF blocks an otherwise verified session before enqueue',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      expect(session.serverVerified, true);
      final scope = session.scope!;
      await db.fence.revokeAccount('child');
      await db.clearAccount('child');
      await expectLater(session.send('mom', 'Blocked'), throwsStateError);
      await expectLater(session.saveShortcuts([]), throwsStateError);
      expect(await session.markRead('mom'), false);
      await session.saveDraft('mom', 'Must not recreate after OFF');
      expect(await db.draft(scope, 'mom'), '');
      expect(await db.outbox(scope), isEmpty);
      expect(api.sendRequests, 0);
    },
  );
  for (final example in [
    (perUnit: 3.25, mass: 5.0, quantity: 2.0, display: '6,50', valid: true),
    (perUnit: .005, mass: 1.0, quantity: 1.0, display: '0,005', valid: false),
    (perUnit: 6.49, mass: 10.0, quantity: 1.0, display: '6,49', valid: true),
  ]) {
    testWidgets(
      'live caregiver shows frozen nutrition and recorded grams: perUnit=${example.perUnit}',
      (tester) async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        final api = FamilyChatTestApi('parent', caregiver: true);
        final session = FamilyChatSession(
          uid: 'parent',
          api: api,
          db: db,
          isCurrentAccount: () => true,
        );
        await session.start();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FamilyChatConversation(
              isCaregiver: true,
              session: session,
              initialTarget: 'mom',
              loadFoods: () async => [
                FamilyChatFoodChoice(
                  name: 'Candy',
                  unit: 'szt.',
                  carbsPerUnit: example.perUnit,
                  gramsPerUnit: example.mass,
                  initialAmount: example.quantity,
                ),
              ],
            ),
          ),
        );
        await tester.tap(find.byTooltip('Wyślij dosłodzenie'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(ChoiceChip, 'Candy'));
        await tester.pumpAndSettle();
        final declaredText = tester
            .widget<TextField>(
              find.byWidgetPredicate(
                (widget) =>
                    widget is TextField &&
                    widget.decoration?.labelText == 'Węglowodany',
              ),
            )
            .controller!
            .text;
        expect(declaredText, example.display);
        final send = find.widgetWithText(FilledButton, 'Wyślij prośbę');
        await tester.ensureVisible(send);
        await tester.tap(send);
        await tester.pumpAndSettle();
        if (!example.valid) {
          expect(api.messages, isEmpty);
          expect(api.sendRequests, 0);
          expect(
            find.text('Zapis wymaga co najmniej 0,5 g WW'),
            findsOneWidget,
          );
          await tester.pumpWidget(const SizedBox.shrink());
          session.dispose();
          await db.close();
          return;
        }
        await session.synchronize();
        final message = api.messages.single;
        expect(message['kind'], 'lowTreatment');
        final snapshot = message['treatment'] as Map;
        expect(snapshot['quantity'], example.quantity);
        expect(snapshot['unit'], 'piece');
        expect(snapshot['gramsPerUnit'], example.mass);
        expect(
          snapshot['carbsPer100g'],
          closeTo(example.perUnit * 100 / example.mass, .000001),
        );
        final frozenCarbs =
            (snapshot['quantity'] as num) *
            (snapshot['gramsPerUnit'] as num) *
            (snapshot['carbsPer100g'] as num) /
            100;
        expect(
          frozenCarbs,
          closeTo(double.parse(declaredText.replaceAll(',', '.')), .000000001),
        );
        expect(snapshot['carbsPerUnit'], example.perUnit);
        expect(
          (snapshot['validUntil'] as int) - session.serverNow,
          inInclusiveRange(29 * 60000, 31 * 60000),
        );
        expect(find.textContaining('w podglądzie'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
        session.dispose();
        await db.close();
      },
    );
  }
  for (final state in [
    'active',
    'expired',
    'restored',
    'serverCompleted',
    'ordinaryAnswer',
    'childReply',
    'otherReply',
    'elsewhere',
    'differentAmount',
    'offlineAmount',
    'restoredAmount',
    'heldAmount',
    'snapshotAmount',
  ]) {
    testWidgets('live consumption is explicit and preserves status: $state', (
      tester,
    ) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      if (state == 'otherReply') {
        api.additionalMembers.add({
          'uid': 'dad',
          'role': 'managingCaregiver',
          'displayName': 'Tata',
        });
      }
      final time = DateTime.now().millisecondsSinceEpoch;
      api.messages.add({
        'id': 'request',
        'senderUid': 'mom',
        'conversationId': state == 'otherReply' ? 'family' : 'direct',
        'text': 'Please eat Candy',
        'kind': state == 'ordinaryAnswer' ? 'question' : 'lowTreatment',
        'answers': state == 'ordinaryAnswer' ? ['Zjadłem'] : [],
        if (state != 'ordinaryAnswer')
          'treatment': {
            'foodName': 'Candy',
            'quantity': 2,
            'unit': 'piece',
            'gramsPerUnit': 5,
            'carbsPer100g': 80,
            'carbs': 8,
            'validUntil': time + (state == 'expired' ? -1000 : 1800000),
          },
        if (state == 'serverCompleted')
          'treatmentResult': {'uid': 'child', 'completedAt': time},
        'sequence': 1,
        'sentAt': time,
        'expiresAt': time + 86400000,
        'receipts': {
          'child': {'deliveredAt': null, 'readAt': null},
        },
      });
      if (state == 'otherReply') {
        api.messages.add({
          'id': 'dad-reply',
          'senderUid': 'dad',
          'conversationId': 'family',
          'text': 'Daj znać',
          'kind': 'answer',
          'answers': [],
          'replyTo': 'request',
          'sequence': 2,
          'sentAt': time + 1,
          'expiresAt': time + 86400000,
          'receipts': <String, dynamic>{},
        });
      }
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      var calls = 0;
      var prepared = false;
      double? selectedQuantity;
      final gate = Completer<({int? mealId, bool acknowledged})>();
      final hydration = Completer<({int? mealId, bool acknowledged})?>();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(
            isCaregiver: false,
            session: session,
            initialTarget: state == 'otherReply' ? 'family' : 'mom',
            confirmTreatment: (_) {
              calls++;
              return gate.future;
            },
            confirmTreatmentQuantity: (_, quantity) {
              calls++;
              prepared = true;
              selectedQuantity = quantity;
              if (state == 'offlineAmount') {
                throw const CallableFailure('unavailable');
              }
              return gate.future;
            },
            confirmTreatmentWithAuthorization: state != 'snapshotAmount'
                ? null
                : (_, quantity, authorization) {
                    calls++;
                    selectedQuantity = quantity;
                    expect(authorization!.accountOffGeneration, 0);
                    expect(session.config!['account']['offGeneration'], 1);
                    return gate.future;
                  },
            loadTreatmentResult: (_) async => state == 'heldAmount'
                ? hydration.future
                : state == 'restored'
                ? (mealId: 42, acknowledged: false)
                : state == 'restoredAmount' ||
                      prepared && state == 'offlineAmount'
                ? (mealId: null, acknowledged: false)
                : null,
            loadTreatmentQuantity: (_) async =>
                ['restoredAmount', 'heldAmount'].contains(state)
                ? 1.5
                : selectedQuantity,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(calls, 0); // Merely receiving/reading never records consumption.
      if (state == 'heldAmount') {
        final original = find.widgetWithText(OutlinedButton, 'Zjadłem');
        expect(tester.widget<OutlinedButton>(original).onPressed, isNull);
        await tester.tap(original);
        expect(calls, 0);
        hydration.complete((mealId: null, acknowledged: false));
        await tester.pumpAndSettle();
      }
      if (state == 'childReply') {
        final no = find.widgetWithText(OutlinedButton, 'Nie mam');
        await tester.ensureVisible(no);
        await tester.tap(no);
        await tester.pumpAndSettle();
        expect(api.messages.last['text'], 'Nie mam');
        expect(calls, 0);
      }
      final button = find.widgetWithText(
        OutlinedButton,
        ['restoredAmount', 'heldAmount'].contains(state)
            ? 'Zjadłem 1,5 szt. — ponów'
            : 'Zjadłem',
      );
      await tester.ensureVisible(button);
      if ([
        'differentAmount',
        'offlineAmount',
        'snapshotAmount',
      ].contains(state)) {
        final other = find.widgetWithText(TextButton, 'Zjadłem inną ilość');
        await tester.ensureVisible(other);
        await tester.tap(other);
        await tester.pumpAndSettle();
        if (state == 'snapshotAmount') {
          session.config!['account'] = {
            ...session.config!['account'] as Map,
            'offGeneration': 1,
          };
        }
        final amount = find.byKey(const ValueKey('consumed-quantity'));
        final confirm = find.widgetWithText(
          FilledButton,
          'Zjadłem — zapisz tę ilość',
        );
        await tester.enterText(amount, '0');
        await tester.tap(confirm);
        await tester.pumpAndSettle();
        expect(calls, 0);
        await tester.enterText(amount, '1,5');
        await tester.tap(confirm);
        await tester.pump();
        expect(calls, 1);
        expect(selectedQuantity, 1.5);
        if (state == 'offlineAmount') {
          await tester.pumpAndSettle();
          expect(
            find.textContaining('Ilość została ustalona: 1,5'),
            findsOneWidget,
          );
          expect(tester.widget<TextButton>(other).onPressed, isNull);
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(
                    OutlinedButton,
                    'Zjadłem 1,5 szt. — ponów',
                  ),
                )
                .onPressed,
            isNotNull,
          );
        } else {
          gate.complete((mealId: 42, acknowledged: true));
          await tester.pumpAndSettle();
          expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        }
      } else if (['expired', 'restored', 'serverCompleted'].contains(state)) {
        expect(tester.widget<OutlinedButton>(button).onPressed, isNull);
        expect(
          find.textContaining(switch (state) {
            'expired' => 'Prośba wygasła',
            'restored' => 'Zapisano dosłodzenie',
            _ => 'Potwierdzono na urządzeniu dziecka',
          }),
          findsOneWidget,
        );
      } else {
        if (['restoredAmount', 'heldAmount'].contains(state)) {
          expect(
            find.textContaining('Ilość została ustalona: 1,5'),
            findsOneWidget,
          );
          expect(
            tester
                .widget<TextButton>(
                  find.widgetWithText(TextButton, 'Zjadłem inną ilość'),
                )
                .onPressed,
            isNull,
          );
        }
        await tester.tap(button);
        await tester.tap(button);
        await tester.pump();
        if (state == 'ordinaryAnswer') {
          await tester.pumpAndSettle();
          expect(calls, 0);
          expect(api.messages.last['kind'], 'answer');
          expect(api.messages.last['text'], 'Zjadłem');
        } else {
          expect(calls, 1);
          gate.complete(
            state == 'elsewhere'
                ? (mealId: null, acknowledged: true)
                : (mealId: 42, acknowledged: false),
          );
          await tester.pumpAndSettle();
          expect(
            find.textContaining(
              state == 'elsewhere'
                  ? 'Potwierdzono na innym urządzeniu'
                  : 'Zapisano dosłodzenie · potwierdzenie oczekuje',
            ),
            findsOneWidget,
          );
          expect(
            tester
                .widget<OutlinedButton>(
                  find.widgetWithText(OutlinedButton, 'Zjadłem'),
                )
                .onPressed,
            isNull,
          );
        }
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      session.dispose();
      await db.close();
    });
  }
  test('cache reload is serialized with a newer local shortcut edit', () async {
    final db = _ShortcutReadGateDb();
    addTearDown(db.close);
    final api = FamilyChatTestApi('child');
    final session = FamilyChatSession(
      uid: 'child',
      api: api,
      db: db,
      isCurrentAccount: () => true,
    );
    addTearDown(session.dispose);
    await session.start();
    final item = {
      'id': 'one',
      'label': 'OK',
      'text': 'Original',
      'answers': <String>[],
      'emoji': '👍',
    };
    await session.saveShortcuts([item]);
    await session.synchronize();
    db.hold = true;
    final sync = session.synchronize();
    await db.entered.future;
    final save = session.saveShortcuts([
      {...item, 'text': 'New local edit'},
    ]);
    db.release.complete();
    await save;
    await sync;
    await session.synchronize();
    expect(session.shortcuts!.single['text'], 'New local edit');
    expect(
      (api.shortcutState['items'] as List).single['text'],
      'New local edit',
    );
  });
  test(
    'a newer offline edit survives restart after an older own commit loses its response',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      FamilyChatSession create() => FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      final first = create();
      await first.start();
      final response = Completer<void>();
      api.shortcutResponseGate = response;
      api.shortcutCommitEntered = Completer<void>();
      final item = {
        'id': 'one',
        'label': 'OK',
        'text': 'First',
        'answers': <String>[],
        'emoji': '👍',
      };
      await first.saveShortcuts([item]);
      await api.shortcutCommitEntered!.future;
      await first.saveShortcuts([
        {...item, 'text': 'Newer offline edit'},
      ]);
      first.dispose();
      await first.synchronize();
      final second = create();
      addTearDown(second.dispose);
      await second.start();
      expect(second.shortcutConflict, false);
      expect(second.shortcutPending, false);
      expect(
        (api.shortcutState['items'] as List).single['text'],
        'Newer offline edit',
      );
      expect(api.shortcutState['revision'], 2);
      response.complete();
    },
  );
  test(
    'offline shortcut edits survive a session restart and resolve a real revision conflict explicitly',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      FamilyChatSession create() => FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      final first = create();
      await first.start();
      final item = {
        'id': 'one',
        'label': 'OK',
        'text': 'Original',
        'answers': <String>[],
        'emoji': '👍',
      };
      await first.saveShortcuts([item]);
      await first.synchronize();
      api.failShortcutFetch = true;
      await first.saveShortcuts([
        {...item, 'text': 'My offline edit'},
      ]);
      await first.synchronize();
      expect(first.shortcutPending, true);
      first.dispose();
      api.shortcutState = {
        ...api.shortcutState,
        'revision': 2,
        'items': [
          {...item, 'text': 'Other device edit'},
        ],
      };
      api.failShortcutFetch = false;
      final second = create();
      addTearDown(second.dispose);
      await second.start();
      expect(second.shortcutConflict, true);
      expect(second.shortcuts!.single['text'], 'My offline edit');
      expect(
        (api.shortcutState['items'] as List).single['text'],
        'Other device edit',
      );
      await second.resolveShortcutConflict(keepMine: true);
      await second.synchronize();
      expect(second.shortcutPending, false);
      expect(
        (api.shortcutState['items'] as List).single['text'],
        'My offline edit',
      );
      api.failShortcutFetch = true;
      await second.saveShortcuts([
        {...item, 'text': 'Discard me'},
      ]);
      await second.synchronize();
      api.shortcutState = {
        ...api.shortcutState,
        'revision': 4,
        'items': [
          {...item, 'text': 'Keep server'},
        ],
      };
      api.failShortcutFetch = false;
      await second.synchronize();
      expect(second.shortcutConflict, true);
      await second.resolveShortcutConflict(keepMine: false);
      expect(second.shortcuts!.single['text'], 'Keep server');
      await second.synchronize();
    },
  );
  test(
    'lost shortcut save response reconciles matching contents without another revision',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      api.failAfterShortcutCommit = true;
      await session.saveShortcuts([
        {
          'id': 'one',
          'label': 'OK',
          'text': 'Full text',
          'answers': <String>[],
          'emoji': '👍',
        },
      ]);
      await session.synchronize();
      await session.synchronize();
      expect(api.shortcutState['revision'], 1);
      expect(session.shortcutPending, false);
    },
  );
  for (final ordering in [false, true]) {
    test(
      'stalled shortcut mutation cannot block later message: order=$ordering',
      () async {
        final db = FamilyChatDatabase(NativeDatabase.memory());
        addTearDown(db.close);
        final api = FamilyChatTestApi('child');
        final session = FamilyChatSession(
          uid: 'child',
          api: api,
          db: db,
          isCurrentAccount: () => true,
        );
        addTearDown(session.dispose);
        await session.start();
        final item = {
          'id': 'one',
          'label': 'OK',
          'text': 'OK',
          'answers': <String>[],
          'emoji': '👍',
        };
        await session.saveShortcuts([item]);
        await session.synchronize();
        final gate = Completer<void>();
        if (ordering) {
          api.shortcutOrderGate = gate;
        } else {
          api.shortcutSaveGate = gate;
        }
        await session.saveShortcuts([item], orderOnly: ordering);
        await session.send('mom', 'Independent message');
        await session.synchronize().timeout(const Duration(seconds: 6));
        expect(api.messages.single['text'], 'Independent message');
        gate.complete();
        await Future<void>.delayed(Duration.zero);
        await session.synchronize();
      },
    );
  }
  test(
    'a stalled shortcut request times out and cannot hold later sends indefinitely',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      api.shortcutFetchGate = Completer<void>();
      api.shortcutFetchEntered = Completer<void>();
      final syncing = session.synchronize();
      await api.shortcutFetchEntered!.future;
      await session.send('mom', 'Queued after shortcut stalled');
      await syncing.timeout(const Duration(seconds: 6));
      expect(api.messages.single['text'], 'Queued after shortcut stalled');
      api.shortcutFetchGate!.complete();
      await session.synchronize();
    },
  );
  testWidgets(
    'a long child reply keeps full text and a valid short wheel label',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      await tester.tap(find.byTooltip('Szybka odpowiedź'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dodaj odpowiedź'));
      await tester.pumpAndSettle();
      const text =
          'Odpiszę po lekcji, teraz nie mogę rozmawiać ale wszystko jest dobrze';
      await tester.enterText(
        find.byWidgetPredicate(
          (widget) =>
              widget is TextField &&
              widget.decoration?.labelText == 'Treść odpowiedzi',
        ),
        text,
      );
      await tester.tap(find.text('Zapisz odpowiedź'));
      await tester.pumpAndSettle();
      await _pumpSync(tester, session);
      final item = (api.shortcutState['items'] as List).last as Map;
      expect(item['text'], text);
      expect((item['label'] as String).length, 40);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'offline wheel deletion keeps visible labels aligned with the selected reply',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      await tester.tap(find.byTooltip('Szybka odpowiedź'));
      await tester.pumpAndSettle();
      api.failShortcutSave = true;
      api.shortcutSaveGate = Completer<void>();
      await tester.longPress(find.text('Już patrzę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń skrót'));
      await tester.pump(const Duration(milliseconds: 50));
      api.shortcutSaveGate!.complete();
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 30));
      });
      await tester.pumpAndSettle();
      expect(find.text('Już patrzę'), findsNothing);
      await tester.tap(find.text('Odpiszę na przerwie'));
      await tester.pumpAndSettle();
      await _pumpSync(tester, session);
      expect(api.messages.single['text'], 'Odpiszę na przerwie');
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
    },
  );
  test(
    'shortcut endpoint failure does not prevent outgoing messages',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      api.failShortcutFetch = true;
      await session.send('mom', 'Still delivered');
      await session.synchronize();
      expect(api.messages.single['text'], 'Still delivered');
      expect(session.error, isNull);
      expect(await db.outbox(session.scope!), isEmpty);
    },
  );
  test(
    'shortcut CRUD and private order survive reopening and offline edits remain durable',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      FamilyChatSession create() => FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      final first = create();
      await first.start();
      final a = {
        'id': 'one',
        'label': 'Przerwa',
        'text': 'Odpiszę na przerwie',
        'answers': <String>[],
        'emoji': '⏰',
      };
      final b = {
        'id': 'two',
        'label': 'OK',
        'text': 'Wszystko dobrze',
        'answers': <String>[],
        'emoji': '👍',
      };
      await first.saveShortcuts([a, b]);
      await first.saveShortcuts([b, a], orderOnly: true);
      await first.synchronize();
      first.dispose();
      final second = create();
      addTearDown(second.dispose);
      await second.start();
      expect(second.shortcuts!.map((item) => item['id']), ['two', 'one']);
      await second.saveShortcuts([
        b,
        {...a, 'label': 'Później', 'emoji': '👀'},
      ]);
      expect(second.shortcuts!.last['emoji'], '👀');
      await second.synchronize();
      api.failShortcutSave = true;
      await second.saveShortcuts([]);
      await second.synchronize();
      expect(second.shortcuts!, isEmpty);
      expect(second.shortcutPending, isTrue);
      api.failShortcutSave = false;
      await second.saveShortcuts([b]);
      await second.synchronize();
      expect(second.shortcuts!.single['id'], 'two');
      await second.invalidate();
      expect(await db.metadata('shortcuts:["child","f","e"]'), isNull);
      expect(await db.metadata('shortcutEdit:["child","f","e"]'), isNull);
    },
  );
  test(
    'large history stays bounded, older page survives sync and unread spans cached pages',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var index = 1; index <= 125; index++) {
        api.messages.add({
          'id': 'message$index',
          'senderUid': 'mom',
          'sequence': index,
          'sentAt': now + index,
          'expiresAt': now + 86400000,
          'text': 'Question $index',
          'receipts': {
            'child': {'deliveredAt': null, 'readAt': null},
          },
        });
      }
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      expect(session.messages('mom').length, 50);
      expect(session.messages('mom').first['sequence'], 76);
      expect(session.unreadCount, 50);
      await session.loadHistory('mom');
      await session.synchronize();
      expect(session.messages('mom').length, 50);
      expect(session.messages('mom').first['sequence'], 26);
      expect(session.unreadCount, 100);
      await session.markRead('mom', ids: {'message26'});
      expect(session.unreadCount, 99);
      await session.loadHistory('mom', latest: true);
      expect(session.messages('mom').first['sequence'], 76);
      expect(session.unreadCount, 99);
      await session.synchronize();
      for (var index = 126; index <= 175; index++) {
        api.messages.add({
          'id': 'message$index',
          'senderUid': 'mom',
          'sequence': index,
          'sentAt': now + index,
          'expiresAt': now + 86400000,
          'text': 'New',
          'receipts': {
            'child': {'deliveredAt': null, 'readAt': null},
          },
        });
      }
      await session.synchronize();
      expect(session.messages('mom').first['sequence'], 126);
      await session.loadHistory('mom');
      expect(session.messages('mom').first['sequence'], 76);
      await session.send('mom', 'Back to latest');
      await session.synchronize();
      expect(session.messages('mom').first['sequence'], 127);
      await session.loadHistory('mom');
      expect(session.messages('mom').first['sequence'], 77);
      await session.synchronize();
    },
  );
  test('older history advances past a fully filtered index page', () async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final api = FamilyChatTestApi('child');
    final now = DateTime.now().millisecondsSinceEpoch;
    for (var index = 1; index <= 125; index++) {
      api.messages.add({
        'id': 'message$index',
        'senderUid': 'mom',
        'sequence': index,
        'sentAt': now,
        'expiresAt': now + 86400000,
        'text': 'Question',
        'hidden': index >= 26 && index <= 75,
        'receipts': {
          'child': {'deliveredAt': null, 'readAt': null},
        },
      });
    }
    final session = FamilyChatSession(
      uid: 'child',
      api: api,
      db: db,
      isCurrentAccount: () => true,
    );
    addTearDown(session.dispose);
    await session.start();
    expect(session.messages('mom').first['sequence'], 76);
    await session.loadHistory('mom');
    await session.loadHistory('mom');
    expect(session.messages('mom').first['sequence'], 1);
    expect(session.messages('mom').last['sequence'], 25);
    await session.synchronize();
  });
  test(
    'receipt refresh updates an old message without a new history sequence',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      await session.send('mom', 'Hello');
      await session.synchronize();
      final sent = api.messages.single;
      (sent['receipts'] as Map)['mom'] = {'deliveredAt': 123, 'readAt': 456};
      await session.synchronize();
      expect(session.messages('mom').single['receipts']['mom']['readAt'], 456);
      expect(api.sendRequests, 1);
    },
  );

  test(
    'marking read persists locally while a network fetch is stalled',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final api = FamilyChatTestApi('child');
      final now = DateTime.now().millisecondsSinceEpoch;
      api.messages.add({
        'id': 'incoming',
        'senderUid': 'mom',
        'sequence': 1,
        'sentAt': now,
        'expiresAt': now + 86400000,
        'text': 'Question',
        'receipts': {
          'child': {'deliveredAt': null, 'readAt': null},
        },
      });
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      addTearDown(session.dispose);
      await session.start();
      api.fetchGate = Completer<void>();
      final sync = session.synchronize();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        await session
            .markRead('mom', ids: {'incoming'})
            .timeout(const Duration(seconds: 1)),
        true,
      );
      expect(session.messages('mom').single['_localRead'], true);
      api.fetchGate!.complete();
      await sync;
      await session.synchronize();
      expect(api.readIds, contains('incoming'));
    },
  );
  test(
    'A to B to A waits for old A cleanup before opening the new A session',
    () async {
      final db = _ClearGate();
      addTearDown(db.close);
      final runtime = FamilyChatRuntime(db)..setForeground(false);
      addTearDown(runtime.dispose);
      await runtime.update('a', true, FamilyChatTestApi('a'));
      await runtime.session!.saveDraft('mom', 'Old A');
      db.held = true;
      final toB = runtime.update('b', true, FamilyChatTestApi('b'));
      await db.entered.future;
      final toA = runtime.update('a', true, FamilyChatTestApi('a'));
      expect(runtime.session, isNull);
      db.release.complete();
      await Future.wait([toB, toA]);
      expect(runtime.session!.uid, 'a');
      expect(runtime.session!.draft('mom'), '');
      await runtime.session!.saveDraft('mom', 'New A');
      await Future<void>.delayed(Duration.zero);
      expect(await db.draft(runtime.session!.scope!, 'mom'), 'New A');
    },
  );

  testWidgets(
    'clearing the field during draft preflight preserves the captured send and never substitutes OK',
    (tester) async {
      final db = _DraftGateDb();
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      try {
        await session.start();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FamilyChatConversation(isCaregiver: false, session: session),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Original snapshot');
        await tester.pump();
        db.holdNextDraft = true;
        await tester.tap(find.byTooltip('Wyślij wiadomość'));
        await db.entered.future;
        await tester.enterText(find.byType(TextField), '');
        db.release.complete();
        await tester.pumpAndSettle();
        await session.synchronize();
        expect(api.messages.single['text'], 'Original snapshot');
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
      } finally {
        if (!db.release.isCompleted) db.release.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await session.synchronize();
        session.dispose();
        await db.close();
      }
    },
  );
  testWidgets(
    'closing during enqueue handoff cannot persist the already consumed composer again',
    (tester) async {
      final db = _HandoffDb();
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      try {
        await session.start();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FamilyChatConversation(isCaregiver: false, session: session),
          ),
        );
        await tester.enterText(find.byType(TextField), 'Handoff');
        await tester.pump();
        db.holdNextOutbox = true;
        await tester.tap(find.byTooltip('Wyślij wiadomość'));
        await db.entered.future;
        expect(await db.draft(session.scope!, 'mom'), '');
        await tester.pumpWidget(const SizedBox.shrink());
        expect(session.draft('mom'), '');
        expect(await db.draft(session.scope!, 'mom'), '');
        db.release.complete();
        await session.synchronize();
        await tester.pumpWidget(
          MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: FamilyChatConversation(isCaregiver: false, session: session),
          ),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          '',
        );
      } finally {
        if (!db.release.isCompleted) db.release.complete();
        await tester.pumpWidget(const SizedBox.shrink());
        await session.synchronize();
        session.dispose();
        await db.close();
      }
    },
  );
  testWidgets(
    'stalled HTTP and a double tap consume the composer once and reopening cannot resurrect it',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child')..sendGate = Completer<void>();
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Tylko raz');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij wiadomość'));
      await tester.tap(find.byTooltip('Wyślij wiadomość'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(await db.draft(session.scope!, 'mom'), '');
      expect(await db.outbox(session.scope!), hasLength(1));
      expect(api.sendRequests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      api.sendGate!.complete();
      await session.synchronize();
      await tester.pumpAndSettle();
      expect(api.messages, hasLength(1));
      expect(api.sendRequests, 1);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'closing immediately persists the full draft and sending a shortcut does not replace it',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Nieukończony szkic ');
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      expect(session.draft('mom'), 'Nieukończony szkic ');
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nieukończony szkic ',
      );
      await tester.tap(find.byTooltip('Szybka odpowiedź'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Już patrzę').first);
      await tester.pumpAndSettle();
      expect(api.messages.single['text'], 'Już patrzę');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Nieukończony szkic ',
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      expect(await db.draft(session.scope!, 'mom'), 'Nieukończony szkic ');
      session.dispose();
      await db.close();
    },
  );
  test(
    'unknown identity hides the session without deleting drafts and resumes after revalidation',
    () async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final runtime = FamilyChatRuntime(db)..setForeground(false);
      addTearDown(runtime.dispose);
      final api = FamilyChatTestApi('child');
      await runtime.update('child', true, api);
      final old = runtime.session!;
      await old.saveDraft('mom', 'Preserved');
      runtime.suspendIdentity();
      expect(runtime.session, isNull);
      expect(old.enabled, isFalse);
      expect(await db.draft(old.scope!, 'mom'), 'Preserved');
      await runtime.update('child', true, api);
      expect(runtime.session!.enabled, isTrue);
      expect(runtime.session!.draft('mom'), 'Preserved');
    },
  );
  testWidgets(
    'draft persistence is not queued behind a stalled network fetch',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      api.fetchGate = Completer<void>();
      final syncing = session.synchronize();
      await session.saveDraft('mom', 'Saved while HTTP waits');
      expect(await db.draft(session.scope!, 'mom'), 'Saved while HTTP waits');
      expect(api.fetchGate!.isCompleted, isFalse);
      api.fetchGate!.complete();
      await syncing;
      expect(session.draft('mom'), 'Saved while HTTP waits');
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'late initial history scrolls to newest before marking only visible messages read',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ListenableBuilder(
            listenable: session,
            builder: (context, _) =>
                FamilyChatConversation(isCaregiver: false, session: session),
          ),
        ),
      );
      await tester.pumpAndSettle();
      api.fetchGate = Completer<void>();
      final now = DateTime.now().millisecondsSinceEpoch;
      for (var index = 0; index < 30; index++) {
        api.messages.add({
          'id': 'incoming$index',
          'senderUid': 'mom',
          'text': 'Wiadomość $index z dłuższej historii rozmowy rodzinnej',
          'kind': 'text',
          'answers': [],
          'sequence': index + 1,
          'sentAt': now,
          'expiresAt': now + 86400000,
          'receipts': {
            'child': {'deliveredAt': null, 'readAt': null},
          },
        });
      }
      final fetching = session.synchronize();
      await tester.pump();
      expect(api.readIds, isEmpty);
      api.fetchGate!.complete();
      await fetching;
      await tester.pumpAndSettle();
      await session.synchronize();
      await tester.pumpAndSettle();
      expect(api.readIds, contains('incoming29'));
      expect(api.readIds, isNot(contains('incoming0')));
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      session.dispose();
      await db.close();
    },
  );
  testWidgets('Home does not poll while a visible conversation does', (
    tester,
  ) async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    final api = FamilyChatTestApi('child');
    final runtime = FamilyChatRuntime(db);
    await runtime.update('child', true, api);
    final homeCount = api.configCalls;
    await tester.pump(const Duration(seconds: 17));
    expect(api.configCalls, homeCount);
    runtime.setChatVisible(true);
    await runtime.session!.synchronize();
    final openedCount = api.configCalls;
    await tester.pump(const Duration(seconds: 9));
    await runtime.session!.synchronize();
    expect(api.configCalls, greaterThan(openedCount));
    runtime.setChatVisible(false);
    final closedCount = api.configCalls;
    await tester.pump(const Duration(seconds: 17));
    expect(api.configCalls, closedCount);
    runtime.dispose();
    await db.close();
  });
  testWidgets(
    'connected history labels actual dates instead of marking every message today',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      for (final day in [16, 17]) {
        api.messages.add({
          'id': 'day$day',
          'senderUid': 'child',
          'text': 'Message $day',
          'kind': 'text',
          'answers': [],
          'sequence': day - 15,
          'sentAt': DateTime(2026, 11, day, 12).millisecondsSinceEpoch,
          'expiresAt': DateTime(2100).millisecondsSinceEpoch,
          'receipts': <String, dynamic>{},
        });
      }
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      expect(find.text('16.11.2026'), findsOneWidget);
      expect(find.text('17.11.2026'), findsOneWidget);
      expect(find.text('Dzisiaj'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await session.synchronize();
      session.dispose();
      await db.close();
    },
  );
  testWidgets(
    'connected view renders roster names and routes typed text without demo messages or watch simulation',
    (tester) async {
      final db = FamilyChatDatabase(NativeDatabase.memory());
      final api = FamilyChatTestApi('child');
      final session = FamilyChatSession(
        uid: 'child',
        api: api,
        db: db,
        isCurrentAccount: () => true,
      );
      await session.start();
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FamilyChatConversation(isCaregiver: false, session: session),
        ),
      );
      expect(find.text('Ola'), findsOneWidget);
      expect(find.text('Mama'), findsNothing);
      expect(find.text('Kuba'), findsNothing);
      expect(find.byTooltip('Podgląd zegarka'), findsNothing);
      await tester.enterText(find.byType(TextField), 'Zjadłem śniadanie ');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij wiadomość'));
      await tester.pumpAndSettle();
      expect(api.messages.single['text'], 'Zjadłem śniadanie');
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '',
      );
      expect(find.text('Zjadłem śniadanie'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      session.dispose();
      await db.close();
      expect(tester.takeException(), isNull);
    },
  );
}
