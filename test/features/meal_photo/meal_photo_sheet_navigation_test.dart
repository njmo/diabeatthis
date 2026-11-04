import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/app/router/guards/initial_configuration_guard.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/widgets/form_step_header.dart';
import 'package:diabeatthis/common/widgets/keyboard_aware_sheet_frame.dart';
import 'package:diabeatthis/features/dashboard/presentation/widgets/dashboard_fab.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/providers/meal_photo_providers.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_action.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_activation_guard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

void main() {
  testWidgets('photo action spans menu width immediately above plan meal', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          anyMealBlockingActivationProvider.overrideWith(
            (ref) => Stream.value(null),
          ),
        ],
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(floatingActionButton: DashboardFAB()),
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    final photo = tester.getRect(find.byType(MealPhotoAction));
    final plan = tester.getRect(find.text('Plan meal'));
    expect(photo.width, greaterThan(300));
    expect(photo.bottom, lessThan(plan.top));
    expect(find.byType(MealPhotoAction), findsOneWidget);
  });

  testWidgets(
    'production photo route opens a sheet and back traverses steps before closing',
    (tester) async {
      final controller = MealPhotoController(
        propose: ProposeMealFromPhotoUseCase(
          client: TestPhotoClient(),
          candidates: TestPhotoCandidates(),
        ),
        saver: TestPhotoSaver(),
      );
      await controller.generate(
        const MealPhotoInput(
          mealPhotoPath: 'plate.jpg',
          description: 'Potatoes and other meal ingredients',
        ),
        languageCode: 'en',
      );
      final container = ProviderContainer(
        overrides: [
          mealPhotoControllerFactoryProvider.overrideWithValue(
            (settings) => controller,
          ),
        ],
      );
      addTearDown(container.dispose);
      final routes = container.read(
        Provider((ref) => AppRouter(InitialConfigurationGuard(ref)).routes),
      );
      final router = RootStackRouter.build(
        routes: [
          NamedRouteDef(
            name: 'PhotoTestHome',
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          routes.firstWhere((route) => route.page.name == MealPhotoRoute.name),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router.config(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      router.push(MealPhotoRoute());
      await tester.pumpAndSettle();
      expect(find.byType(KeyboardAwareSheetFrame), findsOneWidget);
      final bounds = tester.getRect(find.byType(KeyboardAwareSheetFrame));
      expect(bounds.height, lessThan(600));
      expect(find.byType(FormStepHeader), findsOneWidget);
      await tester.ensureVisible(find.text('Divide into ingredients'));
      await tester.tap(find.text('Divide into ingredients'));
      await tester.pumpAndSettle();
      expect(controller.state.step, MealPhotoStep.assignment);
      await router.maybePop();
      await tester.pumpAndSettle();
      expect(controller.state.step, MealPhotoStep.mode);
      expect(find.byType(KeyboardAwareSheetFrame), findsOneWidget);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(controller.state.step, MealPhotoStep.capture);
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
    },
  );
}
