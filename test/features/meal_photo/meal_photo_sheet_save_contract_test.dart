import 'package:auto_route/auto_route.dart';
import 'package:diabeatthis/app/router/app_router.dart';
import 'package:diabeatthis/app/router/guards/initial_configuration_guard.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/meal/meal_category.dart';
import 'package:diabeatthis/features/meal_photo/data/meal_photo_draft_settings.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/accepted_meal_photo_review.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_input.dart';
import 'package:diabeatthis/features/meal_photo/domain/models/meal_photo_proposal.dart';
import 'package:diabeatthis/features/meal_photo/domain/ports/meal_photo_meal_saver.dart';
import 'package:diabeatthis/features/meal_photo/domain/use_cases/propose_meal_from_photo_use_case.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_controller.dart';
import 'package:diabeatthis/features/meal_photo/presentation/controllers/meal_photo_state.dart';
import 'package:diabeatthis/features/meal_photo/presentation/providers/meal_photo_providers.dart';
import 'package:diabeatthis/features/meal_photo/presentation/widgets/meal_photo_timing_summary.dart';
import 'package:diabeatthis/features/meals/data/providers/meal_database_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'meal_photo_controller_test.dart';

class SheetSettingsSaver implements MealPhotoMealSaver {
  late MealPhotoDraftSettings Function() settings;
  MealPhotoDraftSettings? captured;
  int calls = 0;
  @override
  Future<int> save(AcceptedMealPhotoReview review) async {
    captured = settings();
    calls++;
    return 42;
  }
}

Future<MealPhotoController> preparedSheetController(
  SheetSettingsSaver saver,
) async {
  final controller = MealPhotoController(
    propose: ProposeMealFromPhotoUseCase(
      client: TestPhotoClient(),
      candidates: TestPhotoCandidates(),
    ),
    saver: saver,
  );
  await controller.generate(
    const MealPhotoInput(
      mealPhotoPath: 'plate.jpg',
      description: 'Potatoes and other meal ingredients',
    ),
    languageCode: 'en',
  );
  controller.chooseMode(MealPhotoMode.reference);
  controller.acceptReference('plate');
  controller.next();
  controller.setAmount(
    'plate',
    grams: 275,
    quantityConfidence: .6,
    nutritionConfidence: .5,
    reviewed: true,
  );
  controller.next();
  return controller;
}

void main() {
  for (final save in [false, true]) {
    testWidgets(
      save
          ? 'planned photo sheet saves selected timing once and returns its meal ID without starting eating'
          : 'system back visits every review step and preserves physical weight',
      (tester) async {
        final saver = SheetSettingsSaver();
        final controller = await preparedSheetController(saver);
        var mealReads = 0;
        final container = ProviderContainer(
          overrides: [
            mealPhotoControllerFactoryProvider.overrideWithValue((settings) {
              saver.settings = settings;
              return controller;
            }),
            getMealByIdProvider(42).overrideWith((ref) async {
              mealReads++;
              throw StateError('Planned meals must not start eating');
            }),
          ],
        );
        addTearDown(container.dispose);
        final routes = container.read(
          Provider((ref) => AppRouter(InitialConfigurationGuard(ref)).routes),
        );
        final router = RootStackRouter.build(
          routes: [
            NamedRouteDef(
              name: 'SheetSaveHome',
              path: '/',
              builder: (_, _) => const Scaffold(body: Text('Home')),
            ),
            routes.firstWhere(
              (route) => route.page.name == MealPhotoRoute.name,
            ),
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
        final result = router.push<int>(MealPhotoRoute());
        await tester.pumpAndSettle();
        if (!save) {
          for (final step in [
            MealPhotoStep.amounts,
            MealPhotoStep.mode,
            MealPhotoStep.capture,
          ]) {
            await router.maybePop();
            await tester.pumpAndSettle();
            expect(controller.state.step, step);
            if (controller.state.items.isNotEmpty) {
              expect(controller.state.items.single.weightGrams, 275);
            }
          }
          await router.maybePop();
          await tester.pumpAndSettle();
          expect(await result, isNull);
          expect(saver.calls, 0);
          return;
        }
        tester
            .widget<DropdownButtonFormField<MealCategory>>(
              find.byType(
                DropdownButtonFormField<MealCategory>,
                skipOffstage: false,
              ),
            )
            .onChanged!(MealCategory.lunch);
        final future = DateTime.now().add(const Duration(hours: 2));
        tester
            .widget<MealPhotoTimingSummary>(find.byType(MealPhotoTimingSummary))
            .onDateSelected(future);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();
        expect(await result, 42);
        expect(saver.calls, 1);
        expect(saver.captured!.plannedAt, future);
        expect(saver.captured!.category, MealCategory.lunch);
        expect(mealReads, 0);
        expect(find.text('Home'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
