import 'package:diabeatthis/common/auth/google_authentication_providers.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_controller.dart';
import 'package:diabeatthis/common/meal_advisor/demo/meal_decision_demo_request.dart';
import 'package:diabeatthis/common/meal_advisor/presentation/demo/show_meal_decision_demo.dart';
import 'package:diabeatthis/common/theme/application_theme_data.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'all reply controls remain reachable on a narrow screen with large text and keyboard',
    (tester) async {
      LanguageStrings.setSelectedLocale(const Locale('en'));
      addTearDown(() => LanguageStrings.setSelectedLocale(null));
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      final container = ProviderContainer(
        overrides: [
          googleAccountProvider.overrideWith((ref) => Stream.value(null)),
          mealDecisionDemoDelayProvider.overrideWithValue(() async {}),
        ],
      );
      addTearDown(container.dispose);
      await container
          .read(mealDecisionDemoControllerProvider.notifier)
          .send(
            'layout',
            'Rice, white, steamed, Chinese restaurant with chicken and vegetables',
          );
      final request = container.read(
        mealDecisionDemoControllerProvider,
      )['layout']!;
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: applicationThemeData(
              brightness: Brightness.dark,
              textTheme: ThemeData.dark().textTheme,
            ),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(1.6)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => showCaregiverMealDecisionDemo(
                    context,
                    requestKey: request.key,
                    requestId: request.id,
                    caregiverName: 'Anna',
                  ),
                  child: const Text('Open'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      final proceed = find.text('Continue to decision');
      await tester.ensureVisible(proceed);
      await tester.tap(proceed);
      await tester.pumpAndSettle();
      final wait = find.text('Insulin, wait, eat');
      await tester.ensureVisible(wait);
      await tester.tap(wait);
      await tester.pumpAndSettle();
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      await tester.pumpAndSettle();
      final field = find.byType(TextFormField).first;
      await tester.ensureVisible(field);
      await tester.enterText(field, '10');
      final send = find.text('Send to child · demo');
      await tester.ensureVisible(send);
      await tester.tap(send);
      await tester.pumpAndSettle();
      expect(
        container.read(mealDecisionDemoControllerProvider)['layout']!.status,
        MealDecisionDemoStatus.answered,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
