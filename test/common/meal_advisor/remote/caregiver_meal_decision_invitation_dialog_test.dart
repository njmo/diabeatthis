import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/remote/caregiver_meal_decision_invitation_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'invitation shows child name and routes accept and cancel separately',
    (tester) async {
      var accepted = 0;
      var cancelled = 0;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: CaregiverMealDecisionInvitationDialog(
              name: 'Alex Smith',
              busy: false,
              failed: false,
              onAccept: () => accepted++,
              onCancel: () => cancelled++,
              onClose: () {},
            ),
          ),
        ),
      );
      expect(
        find.text('Alex Smith asks you to make a meal decision.'),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Accept')).dx,
        lessThan(tester.getTopLeft(find.text('Decline')).dx),
      );
      await tester.tap(find.text('Accept'));
      expect(accepted, 1);
      expect(cancelled, 0);
      await tester.tap(find.text('Decline'));
      expect(cancelled, 1);
    },
  );

  testWidgets('busy invitation blocks repeated actions and displays failure', (
    tester,
  ) async {
    var calls = 0;
    var closed = 0;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: CaregiverMealDecisionInvitationDialog(
            name: 'Alex Smith',
            busy: true,
            failed: true,
            onAccept: () => calls++,
            onCancel: () => calls++,
            onClose: () => closed++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Accept'));
    await tester.tap(find.text('Decline'));
    expect(calls, 0);
    await tester.tap(find.byTooltip('Close'));
    expect(closed, 1);
    expect(calls, 0);
    expect(
      find.text(
        'Could not update the request. Check the connection and try again.',
      ),
      findsOneWidget,
    );
  });
  testWidgets('invitation fits a narrow screen with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pl'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: const TextScaler.linear(1.5)),
          child: child!,
        ),
        home: Scaffold(
          body: CaregiverMealDecisionInvitationDialog(
            name: 'Aleksandra Kowalska',
            busy: false,
            failed: true,
            onAccept: () {},
            onCancel: () {},
            onClose: () {},
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Akceptuj'), findsOneWidget);
    expect(find.text('Odmów'), findsOneWidget);
  });
}
