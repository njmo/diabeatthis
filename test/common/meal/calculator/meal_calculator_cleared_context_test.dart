import 'package:clock/clock.dart';
import 'package:diabeatthis/common/meal/calculator/calculator_evidence_snapshot.dart';
import 'package:diabeatthis/common/meal/calculator/meal_calculator_request_controller_provider.dart';
import 'package:diabeatthis/common/meal/meal_add_on_bolus_context.dart';
import 'package:diabeatthis/common/meal/meal_calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/bolus_wizard_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/local_mirror/mappers/extended_carb_drift_mapper.dart';
import 'package:diabeatthis/core/data_sources/nightscout/helpers/treatments_factory.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/drift/database_impl.dart'
    show DatabaseImpl, MealCompanion;
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/core/notifications/domain/events/aaps_bolus_suggestion_notification.dart';
import 'package:diabeatthis/core/notifications/providers/notifications_controller_provider.dart';
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../features/meal_summary/domain/use_cases/record_meal_add_on_use_case_test.dart'
    show seedAddOnMeal;
import '../../../foreground/tasks/meal_monitor_test.dart' show testBolusWizard;
import '../../../foreground/utils/fake_notifications_controller.dart';
import '../../../helpers/delivered_meal_bolus.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final fromMirror in [false, true]) {
    test(
      'e-carbs complete PiP after context clearing (mirror: $fromMirror)',
      () => withClock(
        Clock.fixed(DateTime.fromMillisecondsSinceEpoch(1793706928500)),
        () async {
          final started = DateTime.fromMillisecondsSinceEpoch(1793706896964);
          final wizardAt = DateTime.fromMillisecondsSinceEpoch(1793706902052);
          final db = DatabaseImpl(NativeDatabase.memory());
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              notificationsControllerForegroundProvider.overrideWithValue(
                FakeNotificationsController(),
              ),
            ],
          );
          final windows = <List<bool>>[];
          const channel = MethodChannel(
            'pl.diabeatthis.app/calculator_handoff',
          );
          final messenger =
              TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
          messenger.setMockMethodCallHandler(channel, (call) async {
            if (call.method == 'update') {
              windows.add((call.arguments['completed'] as List).cast<bool>());
            }
            if (call.method == 'dismiss') {
              fail('Summarization must not cancel e-carbs');
            }
            return null;
          });
          addTearDown(() async {
            container.dispose();
            await db.close();
            messenger.setMockMethodCallHandler(channel, null);
          });
          await seedAddOnMeal(db, started, status: 'eating-extra');
          final pending = MealAddOnBolusContext(
            originalStatus: 'eating-extra',
            eatingStartedAt: started,
            requestedAt: started,
            coveredCarbs: 0,
            statusCoveredCarbs: 0,
            reportedExtendedCarbs: 15,
            requestedCarbs: 5,
            requestedExtendedCarbs: 15,
            awaitingBolus: true,
            bolusConfirmed: false,
          );
          await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
            MealCompanion(addOnBolusContext: Value(pending.encode())),
          );
          container.read(databaseProvider);
          final controller = container.read(
            mealCalculatorRequestControllerProvider,
          );
          await controller.register(
            const AapsBolusSuggestionNotificationEvent(
              mealId: 1,
              carbs: 5,
              extendedCarbs: 15,
              extendedCarbsDelayMinutes: 45,
              extendedCarbsDurationMinutes: 120,
            ),
            sessionId: 'pip-log',
            openedAt: started,
          );
          final wizard = testBolusWizard(createdAt: wizardAt, carbs: 5);
          await db.localMirrorDao.upsertBolusWizard(
            wizard.toCompanion(TreatmentsSource.aaps),
          );
          await seedDeliveredMealBolus(db, wizardAt);
          final stored = (await db.localMirrorDao.getBolusWizardsBetween(
            wizardAt,
            wizardAt,
          )).single;
          await db.mealWizardLinkDao.link(
            mealId: 1,
            localWizardId: stored.localId,
            relationType: 'initial',
          );
          final submission = resolveMealCalculatorSubmission(wizard, [
            wizard,
            deliveredMealBolus(wizardAt),
          ]);
          expect(submission.isComplete, isTrue);
          await controller.observe(
            CalculatorEvidenceSnapshot([submission], null).toJson(),
          );
          await db.transaction(() async {
            await (db.update(db.meal)..where((row) => row.id.equals(1))).write(
              MealCompanion(
                addOnBolusContext: Value(
                  pending
                      .copyWith(
                        awaitingBolus: false,
                        bolusConfirmed: true,
                        requestedCarbs: 0,
                        acceptedWizardKeys: [
                          'at:${wizardAt.millisecondsSinceEpoch}',
                        ],
                      )
                      .encode(),
                ),
              ),
            );
            await db.mealDao.updateMealStatus(1, 'summarized');
          });
          expect((await db.mealDao.getMealById(1))!.addOnBolusContext, isNull);
          await controller.refresh();
          expect(windows.last, [true, false, false]);
          final extended =
              TreatmentFactory().parseTreatments([
                    {
                      'eventType': 'Meal Bolus',
                      '_id': 'e-carbs-59',
                      'carbs': 15.0,
                      'duration': 7200000,
                      'created_at': DateTime.fromMillisecondsSinceEpoch(
                        1793709627486,
                      ).toUtc().toIso8601String(),
                      'isValid': true,
                    },
                  ]).single
                  as ExtendedCarb;
          if (fromMirror) {
            await db.localMirrorDao.upsertExtendedCarb(
              extended
                  .toCompanion(TreatmentsSource.aaps)
                  .copyWith(receivedAt: const Value(1793706927496)),
            );
            await controller.refresh();
          } else {
            await controller.observe(
              CalculatorEvidenceSnapshot([submission], extended).toJson(),
            );
          }
          expect(windows.last, [true, true, true]);
          expect((await db.mealDao.getMealById(1))!.status, 'summarized');
        },
      ),
    );
  }
}
