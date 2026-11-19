import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_settings_runtime.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/presentation/family_chat_conversation.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';
import 'support/family_chat_test_api.dart';

void main() {
  testWidgets('treatment replies quote the exact request they answer', (
    tester,
  ) async {
    final now = DateTime.now();
    final sent = DateTime(now.year, now.month, now.day, 12, 10);
    final fixture = await _ConversationFixture.create(
      caregiver: true,
      seed: (api) {
        for (var i = 0; i < 2; i++) {
          api.messages.add({
            'id': 'request-$i',
            'kind': 'lowTreatment',
            'senderUid': 'parent',
            'conversationId': 'direct',
            'sequence': i + 1,
            'text': 'Prośba o jogurt',
            'sentAt': sent.add(Duration(minutes: i)).millisecondsSinceEpoch,
            'expiresAt': now
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
            'receipts': {'mom': <String, dynamic>{}},
            'treatment': {
              'foodName': 'Jogurt',
              'quantity': 1,
              'unit': 'portion',
              'carbsPerUnit': 8,
              'validUntil': now
                  .add(const Duration(minutes: 30))
                  .millisecondsSinceEpoch,
            },
          });
        }
        for (var i = 0; i < 2; i++) {
          api.messages.add({
            'id': 'answer-$i',
            'kind': 'answer',
            'senderUid': 'mom',
            'conversationId': 'direct',
            'sequence': i + 3,
            'text': i == 0 ? 'Nie mam' : 'Czuję się dobrze',
            'replyTo': 'request-$i',
            'sentAt': sent.add(Duration(minutes: i + 2)).millisecondsSinceEpoch,
            'expiresAt': now
                .add(const Duration(days: 1))
                .millisecondsSinceEpoch,
            'receipts': {'parent': <String, dynamic>{}},
          });
        }
      },
    );
    await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
    await tester.pumpAndSettle();
    for (final (answer, time) in [
      ('Nie mam', '12:10'),
      ('Czuję się dobrze', '12:11'),
    ]) {
      final bubble = find.ancestor(
        of: find.text(answer),
        matching: find.byType(IntrinsicWidth),
      );
      expect(
        find.descendant(of: bubble, matching: find.textContaining('$time ·')),
        findsOneWidget,
      );
    }
  });

  testWidgets('family and direct circles use their independent server badges', (
    tester,
  ) async {
    final fixture = await _ConversationFixture.create(
      caregiver: false,
      seed: (api) {
        api.unreadByTarget = {'family': true, 'mom': true, 'dad': null};
        api.additionalMembers.add({
          'uid': 'dad',
          'role': 'managingCaregiver',
          'displayName': 'Tata',
        });
      },
    );
    Badge badge(String uid) => tester.widget<Badge>(
      find.descendant(
        of: find.byKey(ValueKey('chat-target-$uid')),
        matching: find.byType(Badge),
      ),
    );
    await tester.pumpWidget(
      localizedMaterialApp(home: fixture.view(initialTarget: 'mom')),
    );
    await tester.pumpAndSettle();
    expect(fixture.session.messages('family'), isEmpty);
    expect(badge('family').isLabelVisible, isTrue);
    expect(badge('mom').isLabelVisible, isTrue);
    expect(badge('dad').isLabelVisible, isFalse);
    expect(fixture.session.hasUnreadIn('dad'), isNull);

    // Another device reads only the direct conversation.
    fixture.api.unreadByTarget!['mom'] = false;
    await fixture.session.synchronize();
    await tester.pumpAndSettle();
    expect(badge('family').isLabelVisible, isTrue);
    expect(badge('mom').isLabelVisible, isFalse);

    await tester.tap(find.byKey(const ValueKey('chat-target-family')));
    await tester.pumpAndSettle();
    fixture.api.unreadByTarget!['mom'] = true;
    await fixture.session.synchronize();
    await tester.pumpAndSettle();
    expect(badge('mom').isLabelVisible, isTrue);
    expect(fixture.api.readIds, isEmpty);
  });

  testWidgets('history clear explains what happens to treatment requests', (
    tester,
  ) async {
    final fixture = await _ConversationFixture.create(caregiver: false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          familyChatSettingsRuntimeProvider.overrideWith((_) => null),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: fixture.view(),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Conversation options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear my history'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Outstanding low-treatment requests'),
      findsOneWidget,
    );
    expect(
      find.textContaining('A confirmation already in progress'),
      findsOneWidget,
    );
    expect(find.textContaining('Recorded treatments remain'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fixture.session.historyClearPending, isFalse);
  });

  testWidgets('group read counts are sourced from recipient receipts', (
    tester,
  ) async {
    final fixture = await _ConversationFixture.create(
      caregiver: true,
      seed: (api) {
        final now = DateTime.now().millisecondsSinceEpoch;
        api.messages.add({
          'id': 'group-message',
          'senderUid': 'parent',
          'conversationId': 'family',
          'text': 'Wiadomość do wszystkich',
          'kind': 'text',
          'sequence': 1,
          'sentAt': now,
          'expiresAt': now + 86400000,
          'names': {'parent': 'Nadawca', 'mom': 'Dziecko', 'dad': 'Tata'},
          'roles': {'mom': 'child', 'dad': 'managingCaregiver'},
          'receipts': {
            'mom': {'deliveredAt': now, 'readAt': now},
            'dad': {'deliveredAt': now, 'readAt': null},
          },
        });
      },
    );
    await tester.pumpWidget(
      localizedMaterialApp(home: fixture.view(initialTarget: 'family')),
    );
    await tester.pumpAndSettle();
    final count = find.byKey(const ValueKey('group-read-count'));
    expect(tester.widget<Text>(count).data, '1/2');
    expect(
      tester.widget<Text>(count).style!.color,
      isNot(const Color(0xFF0EA5E9)),
    );
    await tester.tap(find.byTooltip('Odczyty grupy'));
    await tester.pumpAndSettle();
    expect(find.text('Nadawca'), findsNothing);
    expect(find.text('dziecko'), findsOneWidget);
    expect(find.text('Dostarczona'), findsOneWidget);
    expect(find.textContaining('Przeczytana · '), findsOneWidget);

    await tester.tap(find.byTooltip('Zamknij formularz'));
    await tester.pumpAndSettle();
    final message = fixture.api.messages.single;
    final receipts = message['receipts'] as Map;
    (receipts['dad'] as Map)['readAt'] = message['sentAt'];
    await fixture.session.synchronize();
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(count).data, '2/2');
    expect(tester.widget<Text>(count).style!.color, const Color(0xFF0EA5E9));

    await tester.tap(find.text('Dziecko'));
    await tester.pumpAndSettle();
    expect(count, findsNothing);
  });

  testWidgets('canceling a parent question preserves its composer draft', (
    tester,
  ) async {
    final fixture = await _ConversationFixture.create(caregiver: true);
    await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
    await tester.enterText(find.byType(TextField), 'Kiedy masz przerwę?');
    await tester.pump();
    await tester.tap(find.byTooltip('Wyślij pytanie'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Zamknij formularz'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      'Kiedy masz przerwę?',
    );
    expect(find.byTooltip('Wyślij wiadomość'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'closing the parent screen while a question is open does not use a disposed controller',
    (tester) async {
      final fixture = await _ConversationFixture.create(caregiver: true);
      final chat = MaterialPageRoute<void>(builder: (_) => fixture.view());
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.of(context).push(chat),
                child: const Text('Otwórz'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Otwórz'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Pytanie');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij pytanie'));
      await tester.pumpAndSettle();
      tester.state<NavigatorState>(find.byType(Navigator)).removeRoute(chat);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Zamknij formularz'));
      await tester.pumpAndSettle();
      expect(find.text('Otwórz'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final caregiver in [true, false]) {
    testWidgets(
      'composer switches between acknowledgement and sending: $caregiver',
      (tester) async {
        final fixture = await _ConversationFixture.create(caregiver: caregiver);
        await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
        await tester.tap(find.byTooltip('Wyślij OK'));
        await tester.pumpAndSettle();
        expect(find.text('OK'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget);
        await tester.enterText(find.byType(TextField), 'Test');
        await tester.pumpAndSettle();
        expect(find.byTooltip('Wyślij OK'), findsNothing);
        expect(find.byTooltip('Wyślij wiadomość'), findsOneWidget);
        await tester.enterText(find.byType(TextField), '');
        await tester.pumpAndSettle();
        expect(find.byTooltip('Wyślij OK'), findsOneWidget);
      },
    );
  }
  for (final caregiver in [true, false]) {
    testWidgets('shortcut keeps its selected emoji after editing: $caregiver', (
      tester,
    ) async {
      final fixture = await _ConversationFixture.create(caregiver: caregiver);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            locale: const Locale('pl'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: fixture.view(),
          ),
        ),
      );
      await tester.tap(
        find.byTooltip(caregiver ? 'Szybkie pytanie' : 'Szybka odpowiedź'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(caregiver ? 'Dodaj pytanie' : 'Dodaj odpowiedź'),
      );
      await tester.pumpAndSettle();
      if (caregiver) {
        await tester.enterText(
          find.byWidgetPredicate(
            (w) =>
                w is TextField &&
                w.decoration?.labelText == 'Krótka nazwa na kole',
          ),
          'Mój skrót',
        );
      }
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText ==
                  (caregiver ? 'Treść pytania' : 'Treść odpowiedzi'),
        ),
        caregiver ? 'Masz wszystko?' : 'Mój skrót',
      );
      await tester.tap(find.text('Wybierz emoji'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('emoji-🎒')));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(
        FilledButton,
        caregiver ? 'Zapisz pytanie' : 'Zapisz odpowiedź',
      );
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('🎒'), findsOneWidget);
      await tester.longPress(find.text('Mój skrót'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edytuj skrót'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('🎒'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'saved low treatment product recalculates carbs for chosen quantity',
    (tester) async {
      final fixture = await _ConversationFixture.create(caregiver: true);
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pl'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: fixture.view(
            loadFoods: () async => const [
              FamilyChatFoodChoice(
                name: 'Produkt testowy',
                unit: 'szt.',
                carbsPerUnit: 3.25,
                initialAmount: 1,
                gramsPerUnit: 5,
              ),
            ],
          ),
        ),
      );
      await tester.tap(find.byTooltip('Wyślij dosłodzenie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Produkt testowy'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Ilość (szt.)',
        ),
        '2',
      );
      await tester.pumpAndSettle();
      final carbs = tester.widget<TextField>(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Węglowodany',
        ),
      );
      expect(carbs.controller!.text, '6,50');
      expect(carbs.readOnly, isTrue);
      final send = find.widgetWithText(FilledButton, 'Wyślij prośbę');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.textContaining('2 szt. · Produkt testowy'), findsOneWidget);
      expect(find.textContaining('6,5 g węglowodanów'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  for (final caregiver in [true, false]) {
    testWidgets(
      'shared wheel swaps shortcuts after holding and dragging: $caregiver',
      (tester) async {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final fixture = await _ConversationFixture.create(caregiver: caregiver);
        await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
        await tester.tap(
          find.byTooltip(caregiver ? 'Szybkie pytanie' : 'Szybka odpowiedź'),
        );
        await tester.pumpAndSettle();
        final first = find.text(caregiver ? 'Śniadanie' : 'Już patrzę');
        final second = find.text(caregiver ? 'Woda' : 'Odpiszę na przerwie');
        final firstPosition = tester.getCenter(first);
        final secondPosition = tester.getCenter(second);
        final gesture = await tester.startGesture(firstPosition);
        await tester.pump(const Duration(milliseconds: 600));
        expect(find.text('Edytuj skrót'), findsOneWidget);
        await gesture.moveTo(secondPosition);
        await tester.pump(const Duration(milliseconds: 100));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(tester.getCenter(first).dx, closeTo(secondPosition.dx, 1));
        expect(tester.getCenter(second).dx, closeTo(firstPosition.dx, 1));
        expect(find.text('Edytuj skrót'), findsNothing);
        expect(
          find.byType(Dialog),
          findsOneWidget,
          reason: 'Dragging must not send a message',
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('wheel has one central plus, a close icon and shortcut actions', (
    tester,
  ) async {
    final fixture = await _ConversationFixture.create(caregiver: true);
    await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
    await tester.tap(find.byTooltip('Szybkie pytanie'));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Dodaj pytanie'), findsOneWidget);
    expect(find.text('Moje pytania'), findsNothing);
    expect(find.text('Zamknij'), findsNothing);
    expect(find.byTooltip('Zamknij koło'), findsOneWidget);
    await tester.longPress(find.text('Woda'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Usuń skrót'));
    await tester.pumpAndSettle();
    expect(find.text('Woda'), findsNothing);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
    'child edits quick replies without sending and then selects one',
    (tester) async {
      final fixture = await _ConversationFixture.create(caregiver: false);
      await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
      await tester.tap(find.byTooltip('Szybka odpowiedź'));
      await tester.pumpAndSettle();
      expect(find.text('Dodaj odpowiedź'), findsOneWidget);
      await tester.longPress(find.text('Już patrzę'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edytuj skrót'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField && w.decoration?.labelText == 'Treść odpowiedzi',
        ),
        'Sprawdzę za chwilę',
      );
      await tester.tap(find.text('Zapisz odpowiedź'));
      await tester.pumpAndSettle();
      expect(find.text('Sprawdzę za chwilę'), findsOneWidget);
      await tester.tap(find.text('Sprawdzę za chwilę'));
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      expect(find.text('Sprawdzę za chwilę'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'one-off parent question has no wheel label and creates no template',
    (tester) async {
      final fixture = await _ConversationFixture.create(caregiver: true);
      await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
      await tester.enterText(find.byType(TextField), 'Masz dziś WF?');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij pytanie'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Krótka nazwa na kole',
        ),
        findsNothing,
      );
      await tester.tap(find.text('Wyślij pytanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Szybkie pytanie'));
      await tester.pumpAndSettle();
      expect(find.text('Moje pytanie'), findsNothing);
      expect(find.text('Śniadanie'), findsOneWidget);
    },
  );
  testWidgets(
    'templates can be renamed, edited and deleted without sending a message',
    (tester) async {
      final fixture = await _ConversationFixture.create(caregiver: true);
      await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
      await tester.tap(find.byTooltip('Szybkie pytanie'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Śniadanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edytuj skrót'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              w.decoration?.labelText == 'Krótka nazwa na kole',
        ),
        'Drugie śniadanie',
      );
      await tester.enterText(
        find.byWidgetPredicate(
          (w) => w is TextField && w.decoration?.labelText == 'Treść pytania',
        ),
        'Czy masz dziś kanapkę?',
      );
      await tester.ensureVisible(find.byTooltip('Usuń odpowiedź 3'));
      await tester.tap(find.byTooltip('Usuń odpowiedź 3'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Usuń odpowiedź 2'));
      await tester.pumpAndSettle();
      final save = find.widgetWithText(FilledButton, 'Zapisz pytanie');
      await tester.ensureVisible(save);
      await tester.tap(save);
      await tester.pumpAndSettle();
      expect(find.text('Drugie śniadanie'), findsOneWidget);
      await tester.tap(find.byTooltip('Zamknij koło'));
      await tester.pumpAndSettle();
      expect(find.text('Czy masz dziś kanapkę?'), findsNothing);
      await tester.tap(find.byTooltip('Szybkie pytanie'));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Drugie śniadanie'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Usuń skrót'));
      await tester.pumpAndSettle();
      expect(find.text('Drugie śniadanie'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final count in [0, 1, 2]) {
    testWidgets('question sends exactly $count nonempty proposed replies', (
      tester,
    ) async {
      final fixture = await _ConversationFixture.create(caregiver: true);
      await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
      await tester.enterText(
        find.byType(TextField),
        'Pytanie z $count odpowiedziami',
      );
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij pytanie'));
      await tester.pumpAndSettle();
      expect(
        find.byWidgetPredicate(
          (w) =>
              w is TextField &&
              (w.decoration?.labelText?.startsWith('Odpowiedź') ?? false),
        ),
        findsNothing,
      );
      for (var i = 0; i <= count; i++) {
        await tester.tap(find.byTooltip('Dodaj odpowiedź'));
        await tester.pumpAndSettle();
        if (i < count) {
          await tester.enterText(
            find.byWidgetPredicate(
              (w) =>
                  w is TextField &&
                  w.decoration?.labelText == 'Odpowiedź ${i + 1}',
            ),
            'Opcja ${i + 1}',
          );
        }
      }
      final send = find.widgetWithText(FilledButton, 'Wyślij pytanie');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(fixture.api.sendPayloads.single['answers'], [
        for (var index = 0; index < count; index++) 'Opcja ${index + 1}',
      ]);
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
    'child can type in one conversation and see it only for that recipient',
    (tester) async {
      final fixture = await _ConversationFixture.create(
        caregiver: false,
        seed: (api) => api.additionalMembers.add({
          'uid': 'dad',
          'role': 'managingCaregiver',
          'displayName': 'Tata',
        }),
      );
      await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
      await tester.enterText(find.byType(TextField), 'Mam kanapkę i jabłko');
      await tester.pump();
      await tester.tap(find.byTooltip('Wyślij wiadomość'));
      await tester.pumpAndSettle();
      expect(find.text('Mam kanapkę i jabłko'), findsOneWidget);
      await tester.tap(find.text('Tata').first);
      await tester.pumpAndSettle();
      expect(find.text('Mam kanapkę i jabłko'), findsNothing);
      await tester.tap(find.text('Ola').first);
      await tester.pumpAndSettle();
      expect(find.text('Mam kanapkę i jabłko'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('parent picks a wheel question and defines custom replies', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final fixture = await _ConversationFixture.create(caregiver: true);
    await tester.pumpWidget(localizedMaterialApp(home: fixture.view()));
    await tester.tap(find.byTooltip('Szybkie pytanie'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);
    expect(tester.takeException(), isNull, reason: 'question wheel');
    await tester.tap(find.text('Woda'));
    await tester.pumpAndSettle();
    expect(find.text('Masz wodę do picia?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'Kiedy masz przerwę?');
    await tester.pump();
    await tester.tap(find.byTooltip('Wyślij pytanie'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'question editor');
    await tester.tap(find.byTooltip('Dodaj odpowiedź'));
    await tester.pumpAndSettle();
    final answer = find.byWidgetPredicate(
      (widget) =>
          widget is TextField && widget.decoration?.labelText == 'Odpowiedź 1',
    );
    await tester.enterText(answer, 'Za 10 minut');
    await tester.tap(find.widgetWithText(FilledButton, 'Wyślij pytanie'));
    await tester.pumpAndSettle();
    expect(find.text('Kiedy masz przerwę?'), findsOneWidget);
    expect(find.text('Za 10 minut'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _ConversationFixture {
  _ConversationFixture(this.session, this.api);

  final FamilyChatSession session;
  final FamilyChatTestApi api;

  static Future<_ConversationFixture> create({
    required bool caregiver,
    void Function(FamilyChatTestApi)? seed,
  }) async {
    final db = FamilyChatDatabase(NativeDatabase.memory());
    final api = FamilyChatTestApi(
      caregiver ? 'parent' : 'child',
      caregiver: caregiver,
    );
    seed?.call(api);
    final session = FamilyChatSession(
      uid: api.uid,
      api: api,
      db: db,
      isCurrentAccount: () => true,
    );
    addTearDown(() async {
      session.dispose();
      await db.close();
    });
    await session.start();
    return _ConversationFixture(session, api);
  }

  Widget view({
    String? initialTarget,
    Future<List<FamilyChatFoodChoice>> Function()? loadFoods,
  }) => ListenableBuilder(
    listenable: session,
    builder: (_, _) => FamilyChatConversation(
      isCaregiver: api.caregiver,
      session: session,
      initialTarget: initialTarget,
      loadFoods: loadFoods,
    ),
  );
}
