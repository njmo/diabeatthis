import 'package:diabeatthis/common/family_chat/application/family_chat_session.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/presentation/family_chat_conversation.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/family_chat_test_api.dart';

/// Expected on-screen text per locale. Values are written out literally so
/// the test fails when a widget falls back to hardcoded text or the wrong
/// locale, instead of mirroring translation getters.
class _Expect {
  const _Expect({
    required this.title,
    required this.familySubtitle,
    required this.options,
    required this.quickQuestion,
    required this.quickReply,
    required this.sendTreatment,
    required this.caregiverHint,
    required this.childHint,
    required this.sendOk,
    required this.sendMessage,
    required this.breakfastQuestion,
    required this.breakfastLabel,
    required this.breakfastAnswers,
    required this.treatmentTitle,
    required this.product,
    required this.carbs,
    required this.productRequired,
    required this.sendRequest,
    required this.quantityPieces,
    required this.ate,
    required this.none,
    required this.pieces,
    required this.treatmentBody,
  });

  final String title;
  final String familySubtitle;
  final String options;
  final String quickQuestion;
  final String quickReply;
  final String sendTreatment;
  final String caregiverHint;
  final String childHint;
  final String sendOk;
  final String sendMessage;
  final String breakfastQuestion;
  final String breakfastLabel;
  final List<String> breakfastAnswers;
  final String treatmentTitle;
  final String product;
  final String carbs;
  final String productRequired;
  final String sendRequest;
  final String quantityPieces;
  final String ate;
  final String none;
  final String pieces;
  final String treatmentBody;
}

/// Body produced by backend/family/common/chat_treatment.cjs treatmentText().
const _canonicalTreatmentText = '2 × Candy · 6.5 g WW · zapis 7 g';

const _expectations = {
  'en': _Expect(
    title: 'Chat',
    familySubtitle: 'Family',
    options: 'Conversation options',
    quickQuestion: 'Quick question',
    quickReply: 'Quick reply',
    sendTreatment: 'Send low treatment',
    caregiverHint: 'Message…',
    childHint: 'Type a message…',
    sendOk: 'Send OK',
    sendMessage: 'Send message',
    breakfastQuestion: 'Do you have your snack with you?',
    breakfastLabel: 'Breakfast',
    breakfastAnswers: ['I have it', "Don't have it", "I'll check"],
    treatmentTitle: 'Low treatment',
    product: 'Product',
    carbs: 'Carbohydrates',
    productRequired: 'Enter a product',
    sendRequest: 'Send request',
    quantityPieces: 'Quantity (pcs)',
    ate: 'I ate it',
    none: "I don't have it",
    pieces: 'pcs',
    treatmentBody:
        'Please eat: 2 pcs · Candy.\nTotal 6.5 g carbohydrates. Low treatment entry: 7 g.',
  ),
  'pl': _Expect(
    title: 'Rozmowy',
    familySubtitle: 'Rodzina',
    options: 'Opcje rozmowy',
    quickQuestion: 'Szybkie pytanie',
    quickReply: 'Szybka odpowiedź',
    sendTreatment: 'Wyślij dosłodzenie',
    caregiverHint: 'Wiadomość…',
    childHint: 'Napisz wiadomość…',
    sendOk: 'Wyślij OK',
    sendMessage: 'Wyślij wiadomość',
    breakfastQuestion: 'Masz przy sobie drugie śniadanie?',
    breakfastLabel: 'Śniadanie',
    breakfastAnswers: ['Mam', 'Nie mam', 'Sprawdzę'],
    treatmentTitle: 'Dosłodzenie',
    product: 'Produkt',
    carbs: 'Węglowodany',
    productRequired: 'Podaj produkt',
    sendRequest: 'Wyślij prośbę',
    quantityPieces: 'Ilość (szt.)',
    ate: 'Zjadłem',
    none: 'Nie mam',
    pieces: 'szt.',
    treatmentBody:
        'Proszę, zjedz: 2 szt. · Candy.\nŁącznie 6,5 g węglowodanów. Wpis dosłodzenia: 7 g.',
  ),
};

Future<FamilyChatSession> _session(
  FamilyChatTestApi api, {
  void Function(FamilyChatTestApi)? seed,
}) async {
  final db = FamilyChatDatabase(NativeDatabase.memory());
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
  return session;
}

Widget _app(
  String locale,
  FamilyChatSession session, {
  required bool caregiver,
  String? initialTarget,
  Future<List<FamilyChatFoodChoice>> Function()? loadFoods,
}) => MaterialApp(
  locale: Locale(locale),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: ListenableBuilder(
    listenable: session,
    builder: (_, _) => FamilyChatConversation(
      isCaregiver: caregiver,
      session: session,
      initialTarget: initialTarget,
      loadFoods: loadFoods,
    ),
  ),
);

Finder _field(String label) => find.byWidgetPredicate(
  (w) => w is TextField && w.decoration?.labelText == label,
);

void main() {
  for (final MapEntry(key: locale, value: text) in _expectations.entries) {
    final other = _expectations.entries
        .firstWhere((entry) => entry.key != locale)
        .value;

    testWidgets('$locale: caregiver heading, composer and actions', (
      tester,
    ) async {
      final session = await _session(
        FamilyChatTestApi('parent', caregiver: true),
      );
      await tester.pumpWidget(_app(locale, session, caregiver: true));
      await tester.pumpAndSettle();

      expect(find.text(text.title), findsWidgets);
      expect(find.text(text.familySubtitle), findsWidgets);
      expect(find.byTooltip(text.options), findsOneWidget);
      expect(find.byTooltip(other.options), findsNothing);
      expect(find.byTooltip(text.quickQuestion), findsOneWidget);
      expect(find.byTooltip(text.sendTreatment), findsOneWidget);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.decoration?.hintText, text.caregiverHint);

      expect(find.byTooltip(text.sendOk), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'abc');
      await tester.pump();
      expect(find.byTooltip(text.sendMessage), findsOneWidget);
      expect(find.byTooltip(text.sendOk), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$locale: default wheel shows short label and sends question', (
      tester,
    ) async {
      final api = FamilyChatTestApi('parent', caregiver: true);
      final session = await _session(api);
      await tester.pumpWidget(_app(locale, session, caregiver: true));
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(text.quickQuestion));
      await tester.pumpAndSettle();
      // The wheel shows short labels only; the full question is sent on tap.
      expect(find.text(text.breakfastLabel), findsOneWidget);
      expect(find.text(other.breakfastLabel), findsNothing);
      await tester.tap(find.text(text.breakfastLabel));
      await tester.pumpAndSettle();

      final sent = api.messages.last;
      expect(sent['kind'], 'question');
      expect(sent['text'], text.breakfastQuestion);
      expect(sent['answers'], text.breakfastAnswers);
      expect(find.text(text.breakfastQuestion), findsOneWidget);
      expect(find.text(other.breakfastQuestion), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$locale: child composer and quick reply action', (
      tester,
    ) async {
      final session = await _session(FamilyChatTestApi('child'));
      await tester.pumpWidget(_app(locale, session, caregiver: false));
      await tester.pumpAndSettle();

      expect(find.text(text.title), findsWidgets);
      expect(find.byTooltip(text.quickReply), findsOneWidget);
      expect(find.byTooltip(text.sendTreatment), findsNothing);
      final composer = tester.widget<TextField>(find.byType(TextField));
      expect(composer.decoration?.hintText, text.childHint);
    });

    testWidgets('$locale: low-treatment request form labels and validation', (
      tester,
    ) async {
      final api = FamilyChatTestApi('parent', caregiver: true);
      final session = await _session(api);
      await tester.pumpWidget(
        _app(
          locale,
          session,
          caregiver: true,
          loadFoods: () async => const [
            FamilyChatFoodChoice(
              name: 'Juice',
              unit: 'szt.',
              carbsPerUnit: 3,
              initialAmount: 1,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip(text.sendTreatment));
      await tester.pumpAndSettle();
      expect(find.text(text.treatmentTitle), findsWidgets);
      expect(_field(text.product), findsOneWidget);
      expect(_field(text.carbs), findsOneWidget);
      expect(_field(other.product), findsNothing);

      // Empty product must be rejected with a localized message and nothing
      // may be sent.
      final send = find.widgetWithText(FilledButton, text.sendRequest);
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(find.text(text.productRequired), findsOneWidget);
      expect(find.text(other.productRequired), findsNothing);
      expect(api.messages, isEmpty);

      // A food choice that still carries a legacy Polish unit is shown in
      // the active locale.
      await tester.tap(find.widgetWithText(ChoiceChip, 'Juice'));
      await tester.pumpAndSettle();
      expect(_field(text.quantityPieces), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('$locale: canonical low-treatment body renders from snapshot', (
      tester,
    ) async {
      final time = DateTime.now().millisecondsSinceEpoch;
      final session = await _session(
        FamilyChatTestApi('child'),
        seed: (api) => api.messages.add({
          'id': 'request',
          'senderUid': 'mom',
          'conversationId': 'direct',
          'text': _canonicalTreatmentText,
          'kind': 'lowTreatment',
          'answers': [],
          'treatment': {
            'foodName': 'Candy',
            'quantity': 2,
            'unit': 'piece',
            'gramsPerUnit': 5,
            'carbsPer100g': 65,
            'carbsPerUnit': 3.25,
            'grams': 10,
            'carbs': 6.5,
            'deliveryCarbs': 7,
            'validUntil': time + 1800000,
          },
          'sequence': 1,
          'sentAt': time,
          'expiresAt': time + 86400000,
          'receipts': {
            'child': {'deliveredAt': null, 'readAt': null},
          },
        }),
      );
      await tester.pumpWidget(
        _app(locale, session, caregiver: false, initialTarget: 'mom'),
      );
      await tester.pumpAndSettle();

      // The canonical backend body is Polish; the verified snapshot is
      // rendered in the viewer locale instead, without touching the wire text.
      expect(find.text(text.treatmentBody), findsOneWidget);
      expect(find.text(other.treatmentBody), findsNothing);
      expect(find.text(_canonicalTreatmentText), findsNothing);
      expect(session.messages('mom').single['text'], _canonicalTreatmentText);
      expect(find.widgetWithText(OutlinedButton, text.ate), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, text.none), findsOneWidget);
      if (text.ate != other.ate) {
        expect(find.widgetWithText(OutlinedButton, other.ate), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('user-authored question answers are not translated', (
    tester,
  ) async {
    final time = DateTime.now().millisecondsSinceEpoch;
    final session = await _session(
      FamilyChatTestApi('child'),
      seed: (api) => api.messages.add({
        'id': 'question',
        'senderUid': 'mom',
        'conversationId': 'direct',
        'text': 'Zjadłeś obiad?',
        'kind': 'question',
        'answers': ['Zjadłem', 'Nie mam'],
        'sequence': 1,
        'sentAt': time,
        'expiresAt': time + 86400000,
        'receipts': {
          'child': {'deliveredAt': null, 'readAt': null},
        },
      }),
    );
    await tester.pumpWidget(
      _app('en', session, caregiver: false, initialTarget: 'mom'),
    );
    await tester.pumpAndSettle();

    expect(find.text('Zjadłeś obiad?'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Zjadłem'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Nie mam'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'I ate it'), findsNothing);
  });
}
