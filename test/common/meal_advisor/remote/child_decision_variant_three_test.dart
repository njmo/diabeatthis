import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/child_meal_decision_answer.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/meal_decision_caregiver_roster.dart';
import 'package:diabeatthis/common/meal_advisor/remote/meal_decision_remote_request.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'deferral explains action, attribution, actual new time and long message',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 640));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      const message =
          'Please wait until the lesson finishes. We will check the meal together afterwards. This is an additional message from your caregiver.';
      final time = DateTime(2026, 11, 8, 17, 30);
      final request = MealDecisionRemoteRequest({
        'response': {
          'caregiverName': 'Marcin Kłonica',
          'caregiverUid': 'parent',
          'respondedAt': time.millisecondsSinceEpoch,
          'type': 'deferMeal',
          'minutes': 45,
          'message': message,
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: const TextScaler.linear(1.5)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: ChildMealDecisionAnswer(request: request),
            ),
          ),
        ),
      );
      expect(find.text('Answered'), findsOneWidget);
      expect(find.text('Decision: Marcin Kłonica'), findsOneWidget);
      expect(find.text('Postpone the meal by 45 minutes'), findsOneWidget);
      expect(find.text('New time: 18:15'), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      await tester.ensureVisible(find.text(message));
      expect(tester.takeException(), isNull);
    },
  );

  test('deferral uses localized minute plurals', () async {
    final pl = await AppLocalizations.delegate.load(const Locale('pl'));
    final en = await AppLocalizations.delegate.load(const Locale('en'));
    expect(pl.mealDecisionDeferAction(1), 'Odłóż posiłek o 1 minutę');
    expect(pl.mealDecisionDeferAction(2), 'Odłóż posiłek o 2 minuty');
    expect(pl.mealDecisionDeferAction(45), 'Odłóż posiłek o 45 minut');
    expect(en.mealDecisionDeferAction(1), 'Postpone the meal by 1 minute');
  });

  testWidgets('deferral across midnight includes the new date', (tester) async {
    final request = MealDecisionRemoteRequest({
      'response': {
        'caregiverName': 'Alex',
        'caregiverUid': 'parent',
        'respondedAt': DateTime(2026, 11, 8, 23, 45).millisecondsSinceEpoch,
        'type': 'deferMeal',
        'minutes': 45,
      },
    });
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ChildMealDecisionAnswer(request: request)),
      ),
    );
    final context = tester.element(find.byType(ChildMealDecisionAnswer));
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(DateTime(2026, 11, 9));
    expect(find.text('New time: $date · 00:30'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final stage in ['context', 'decision']) {
    testWidgets('active caregiver shows matching stage chip: $stage', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MealDecisionCaregiverStatus(
              request: MealDecisionRemoteRequest({
                'claimedByUid': 'parent',
                'stage': stage,
                'presentUntil': DateTime.now()
                    .add(const Duration(minutes: 1))
                    .millisecondsSinceEpoch,
              }),
              member: const {'uid': 'parent', 'displayName': 'Marcin Kłonica'},
            ),
          ),
        ),
      );
      expect(
        find.text(stage == 'context' ? 'Meal review' : 'Choosing a decision'),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
