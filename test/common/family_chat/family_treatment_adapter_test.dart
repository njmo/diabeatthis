import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:diabeatthis/common/app_mode/application_device_mode.dart';
import 'package:diabeatthis/common/backend/authenticated_callable_transport.dart';
import 'package:diabeatthis/common/family_chat/application/family_chat_consumption_action.dart';
import 'package:diabeatthis/common/family_chat/application/family_treatment_adapter.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_database.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_guard_fence.dart';
import 'package:diabeatthis/common/family_chat/data/family_chat_remote.dart';
import 'package:diabeatthis/common/family_chat/domain/family_treatment_authorization.dart';
import 'package:diabeatthis/common/family_chat/domain/family_treatment_carbs.dart';
import 'package:diabeatthis/common/handoff/controllers/handoff_controller.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/core/data/provider/initial_configuration_provider.dart';
import 'package:diabeatthis/core/data/provider/shared_prefs_provider.dart';
import 'package:diabeatthis/core/drift/database_impl.dart';
import 'package:diabeatthis/core/drift/providers/database_provider.dart';
import 'package:diabeatthis/features/low_treatment/application/nightscout_low_treatment_settings.dart';
import 'package:diabeatthis/features/low_treatment/application/open_low_treatment_aaps_use_case.dart';
import 'package:diabeatthis/features/low_treatment/data/providers/low_treatment_upload_provider.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/aaps_carbs_request_episode_store.dart';
import 'package:diabeatthis/features/low_treatment/data/repositories/recorded_low_treatment_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/low_treatment/application/low_treatment_aaps_handoff_test.dart'
    show LowTreatmentGatewayFake, LowTreatmentLauncherFake;

class _Api implements FamilyChatApi {
  _Api(
    this.medical,
    this.reference, {
    this.fractional = false,
    this.sourceNutrition,
    this.offline = false,
  });
  final DatabaseImpl medical;
  final bool reference;
  final bool fractional;
  final double? sourceNutrition;
  final bool offline;
  int claims = 0;
  int calls = 0;
  @override
  Future<Map<String, dynamic>> call(
    String name,
    Map<String, Object?> data, {
    Future<bool> Function()? allowRequest,
  }) async {
    if (allowRequest != null && !await allowRequest()) {
      throw const CallableFailure('cancelled');
    }
    calls++;
    if (offline) throw const CallableFailure('unavailable');
    if (name == 'getFamilyChatConfig') {
      return {
        'uid': 'child',
        'familyId': 'family',
        'epoch': 'epoch',
        'account': {'enabled': true, 'offGeneration': 0},
        'policy': {'enabled': true, 'offGeneration': 0},
        'members': [
          {'uid': 'child', 'role': 'child'},
        ],
      };
    }
    if (name == 'claimFamilyChatTreatment') {
      claims++;
      final row = await medical
          .customSelect('SELECT claim_id FROM family_treatment_journal')
          .getSingle();
      if (sourceNutrition != null) {
        final quantity = (data['quantity'] as num?)?.toDouble() ?? 1.0;
        final nutrition = familyTreatmentNutritionCarbs(
          sourceNutrition! * quantity,
        );
        return {
          'claimId': row.read<String>('claim_id'),
          'serverTime': 1000,
          'executionUntil': 61000,
          'treatment': {
            'foodName': 'PRIVATE_FOOD_NAME',
            'unit': 'portion',
            'quantity': quantity,
            'grams': null,
            'gramsPerUnit': null,
            'carbsPer100g': null,
            'carbsPerUnit': sourceNutrition,
            'carbs': nutrition,
            'deliveryCarbs': familyTreatmentRecordedCarbs(nutrition),
          },
        };
      }
      return {
        'claimId': row.read<String>('claim_id'),
        'serverTime': 1000,
        'executionUntil': 61000,
        'treatment': {
          'foodName': 'PRIVATE_FOOD_NAME',
          'unit': reference ? 'portion' : 'piece',
          'quantity': fractional ? 1 : 2,
          'grams': reference ? null : 10,
          'carbsPer100g': reference
              ? null
              : fractional
              ? 64.9
              : 80,
          'carbsPerUnit': fractional ? 6.49 : 4,
          'carbs': fractional ? 6.49 : 8,
          'deliveryCarbs': fractional ? 6 : 8,
        },
      };
    }
    if (name == 'completeFamilyChatTreatment') return {'ok': true};
    if (name == 'acknowledgeFamilyChatMessages') return {'ok': true};
    throw StateError(name);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final alternate in [false, true]) {
    test(
      'background action respects persisted quantity across real isolates and restart: alternate=$alternate',
      () async {
        SharedPreferences.setMockInitialValues({
          initialConfigurationDoneKey: true,
        });
        final prefs = await SharedPreferences.getInstance();
        final directory = await Directory.systemTemp.createTemp(
          'chat-consumption-restart-',
        );
        Future<
          ({
            Map<String, dynamic> payload,
            String proof,
            int meals,
            int claims,
            FamilyConsumptionNotice state,
          })
        >
        phase(
          bool offline, {
          Map<String, dynamic>? oldPayload,
          bool repeat = false,
        }) async {
          final medical = DatabaseImpl(
            NativeDatabase.createInBackground(
              File('${directory.path}/medical.sqlite'),
            ),
          );
          final chat = FamilyChatDatabase(
            NativeDatabase.createInBackground(
              File('${directory.path}/chat.sqlite'),
            ),
            SqliteChatGuardFence(
              NativeDatabase.createInBackground(
                File('${directory.path}/guard.sqlite'),
              ),
            ),
          );
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(medical),
              sharedPrefsProvider.overrideWith((ref) async => prefs),
            ],
          );
          final api = _Api(
            medical,
            false,
            offline: offline,
            sourceNutrition: alternate ? 6.5 : null,
          );
          final guard = oldPayload == null ? null : await chat.activeChat();
          if (oldPayload == null) {
            await medical.customStatement(
              "UPDATE family_sync_identity SET owner_uid='child' WHERE singleton=1",
            );
            await chat.activateChat(
              'child',
              jsonEncode(['child', 'family', 'epoch']),
              'stamp',
            );
          }
          final expected = guard ?? await chat.activeChat();
          await chat.saveMessage(expected['scope'] as String, 'mom', {
            'id': 'request',
            'kind': 'lowTreatment',
            'senderUid': 'mom',
            'historyGeneration': 0,
            'sequence': 1,
            'sentAt': 1000,
          });
          final payload =
              oldPayload ??
              {
                'type': 'familyChat',
                ...expected,
                'messageId': 'request',
                'target': 'mom',
                'authorization': {
                  'epoch': 'epoch',
                  'accountOffGeneration': 0,
                  'familyOffGeneration': 0,
                },
              };
          final provider = Provider(
            (ref) => createFamilyTreatmentExecutor(
              ref,
              chatDb: chat,
              api: api,
              currentUid: () => 'child',
              expectedGuard: expected,
              observedAuthorization: () =>
                  parseFamilyTreatmentAuthorization(payload['authorization']),
            ),
          );
          final subscription = container.listen(provider, (_, _) {});
          FamilyConsumptionNotice? shown;
          Future<void> handle() async {
            expect(
              await handleFamilyChatConsumption(
                db: chat,
                api: api,
                payload: payload,
                currentUid: () => 'child',
                confirm: (id, _) => subscription.read().confirm(
                  id,
                  actualQuantity: alternate && offline ? 1.5 : null,
                ),
                lookup: (id, _) => subscription.read().lookup(id),
                show: (notice, state, _) async {
                  expect(await chat.hasCancellationIntent(notice), true);
                  shown = state;
                },
                cancel: (_) async {},
              ),
              true,
            );
          }

          try {
            await handle();
            if (alternate && !offline) {
              expect(shown, FamilyConsumptionNotice.unavailable);
              expect(await medical.select(medical.meal).get(), isEmpty);
              expect(api.claims, 0);
              await subscription.read().confirm('request', actualQuantity: 1.5);
            }
            if (repeat) await handle();
            final row = await medical
                .customSelect('SELECT proof FROM family_treatment_journal')
                .getSingle();
            return (
              payload: payload,
              proof: row.read<String>('proof'),
              meals: (await medical.select(medical.meal).get()).length,
              claims: api.claims,
              state: shown!,
            );
          } finally {
            subscription.close();
            container.dispose();
            await chat.close();
            await medical.close();
          }
        }

        try {
          final offline = await phase(true);
          expect(offline.meals, 0);
          expect(offline.claims, 0);
          expect(offline.state, FamilyConsumptionNotice.pending);
          final online = await phase(
            false,
            oldPayload: offline.payload,
            repeat: true,
          );
          expect(online.proof, offline.proof);
          expect(online.meals, 1);
          expect(online.claims, 1);
          expect(online.state, FamilyConsumptionNotice.recorded);
        } finally {
          await directory.delete(recursive: true);
        }
      },
    );
  }
  for (final example in [
    (
      reference: false,
      fractional: false,
      source: null,
      actual: null,
      nutrition: 8.0,
      delivery: 8,
    ),
    (
      reference: true,
      fractional: false,
      source: null,
      actual: null,
      nutrition: 8.0,
      delivery: 8,
    ),
    (
      reference: false,
      fractional: true,
      source: null,
      actual: null,
      nutrition: 6.49,
      delivery: 6,
    ),
    (
      reference: true,
      fractional: false,
      source: .5,
      actual: null,
      nutrition: .5,
      delivery: 1,
    ),
    (
      reference: true,
      fractional: false,
      source: 6.5,
      actual: null,
      nutrition: 6.5,
      delivery: 7,
    ),
    (
      reference: true,
      fractional: false,
      source: 6.4999994,
      actual: null,
      nutrition: 6.499999,
      delivery: 6,
    ),
    (
      reference: true,
      fractional: false,
      source: 6.4999996,
      actual: null,
      nutrition: 6.5,
      delivery: 7,
    ),
    (
      reference: true,
      fractional: false,
      source: 6.5,
      actual: 1.5,
      nutrition: 9.75,
      delivery: 10,
    ),
  ]) {
    final reference = example.reference, fractional = example.fractional;
    test(
      'clinical nutrition, upload and AAPS agree without food logs: nutrition=${example.nutrition} delivery=${example.delivery}',
      () async {
        final now = DateTime(2026, 11, 18, 12);
        await withClock(Clock.fixed(now), () async {
          SharedPreferences.setMockInitialValues({
            initialConfigurationDoneKey: true,
          });
          final prefs = await SharedPreferences.getInstance();
          final medical = DatabaseImpl(NativeDatabase.memory());
          final chat = FamilyChatDatabase(NativeDatabase.memory());
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(medical),
              sharedPrefsProvider.overrideWith((ref) async => prefs),
              nightscoutLowTreatmentSettingsLoaderProvider.overrideWithValue(
                () async => const NightscoutLowTreatmentSettings(
                  enabled: true,
                  url: 'https://unit.invalid',
                  token: 'unit-test',
                  revision: 'r',
                ),
              ),
            ],
          );
          final api = _Api(
            medical,
            reference,
            fractional: fractional,
            sourceNutrition: example.source,
          );
          final provider = Provider(
            (ref) => createFamilyTreatmentExecutor(
              ref,
              chatDb: chat,
              api: api,
              currentUid: () => 'child',
            ),
          );
          final subscription = container.listen(provider, (_, _) {});
          try {
            await medical.customStatement(
              "UPDATE family_sync_identity SET owner_uid='child' WHERE singleton=1",
            );
            await chat.activateChat(
              'child',
              jsonEncode(['child', 'family', 'epoch']),
              'stamp',
            );
            await chat
                .saveMessage(jsonEncode(['child', 'family', 'epoch']), 'mom', {
                  'id': 'request',
                  'kind': 'lowTreatment',
                  'senderUid': 'mom',
                  'historyGeneration': 0,
                  'sequence': 1,
                  'sentAt': 1000,
                });
            final output = <String>[];
            final episode = SharedPreferencesAapsCarbsRequestEpisodeStore(loadPreferences: () async => prefs);
            final observedAt = now.subtract(const Duration(minutes: 1));
            await episode.start('${observedAt.microsecondsSinceEpoch}:test');
            await episode.acceptStatus(observedAt, 8);
            final handoffs = <int>[];
            final result = await runZoned(
              () => subscription.read().confirm(
                'request',
                actualQuantity: example.actual,
                onSaved: (id) async { handoffs.add(id); },
                acceptedAuthorization: (
                  epoch: 'epoch',
                  accountOffGeneration: 0,
                  familyOffGeneration: 0,
                ),
              ),
              zoneSpecification: ZoneSpecification(
                print: (_, _, _, line) => output.add(line),
              ),
            );
            expect(result.mealId, isNotNull);
            expect(handoffs, [result.mealId]);
            final record = await RecordedLowTreatmentRepository(
              medical,
            ).fetchByMealId(result.mealId!);
            expect(record!.netCarbsGrams, example.delivery);
            expect(
              record.historicalNutritionCarbsGrams,
              closeTo(example.nutrition, .000001),
            );
            expect(
              (await medical.select(medical.lowTreatmentUpload).get())
                  .single
                  .carbs,
              example.delivery,
            );
            expect(
              (await medical.select(medical.lowTreatmentHandoff).get())
                  .single
                  .expectedCarbs,
              example.delivery,
            );
            expect(
              (await medical.select(medical.lowTreatmentHandoff).getSingle()).suggestionAt,
              observedAt.millisecondsSinceEpoch,
            );
            final gateway = LowTreatmentGatewayFake(),
                launcher = LowTreatmentLauncherFake();
            await OpenLowTreatmentAapsUseCase(
              loadRecorded: RecordedLowTreatmentRepository(
                medical,
              ).fetchByMealId,
              handoff: HandoffController(gateway),
              launcher: launcher,
            )(result.mealId!, lookupAppLocalizations(const Locale('pl')));
            expect(
              gateway.instruction!.steps.single.value,
              '${example.delivery} g',
            );
            expect(launcher.calls, 0);
            expect(record.eatenAt, now);
            expect(output.join('\n'), isNot(contains('PRIVATE_FOOD_NAME')));
            expect(
              (await medical.select(medical.lowTreatmentHandoff).get())
                  .single
                  .mealId,
              result.mealId,
            );
            expect(
              (await subscription.read().confirm('request', onSaved: (id) async { handoffs.add(id); })).mealId,
              result.mealId,
            );
            expect(handoffs, [result.mealId]);
            expect(await medical.select(medical.meal).get(), hasLength(1));
          } finally {
            subscription.close();
            container.dispose();
            await chat.close();
            await medical.close();
          }
        });
      },
    );
  }
  for (final invalid in ['caregiver', 'otherOwner', 'notConfigured']) {
    test(
      'clinical adapter denies $invalid before preparing any intent or HTTP',
      () async {
        SharedPreferences.setMockInitialValues({
          initialConfigurationDoneKey: invalid != 'notConfigured',
          if (invalid == 'caregiver') applicationDeviceModeKey: 'caregiver',
        });
        final prefs = await SharedPreferences.getInstance();
        final medical = DatabaseImpl(NativeDatabase.memory()),
            chat = FamilyChatDatabase(NativeDatabase.memory());
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(medical),
            sharedPrefsProvider.overrideWith((ref) async => prefs),
          ],
        );
        final api = _Api(medical, false);
        final provider = Provider(
          (ref) => createFamilyTreatmentExecutor(
            ref,
            chatDb: chat,
            api: api,
            currentUid: () => 'child',
            observedAuthorization: () => (
              epoch: 'epoch',
              accountOffGeneration: 0,
              familyOffGeneration: 0,
            ),
          ),
        );
        final subscription = container.listen(provider, (_, _) {});
        try {
          await medical.customStatement(
            'UPDATE family_sync_identity SET owner_uid=? WHERE singleton=1',
            [invalid == 'otherOwner' ? 'other' : 'child'],
          );
          await chat.activateChat(
            'child',
            jsonEncode(['child', 'family', 'epoch']),
            'stamp',
          );
          await expectLater(
            subscription.read().confirm('request'),
            throwsStateError,
          );
          expect(api.calls, 0);
          expect(
            await medical
                .customSelect('SELECT * FROM family_treatment_journal')
                .get(),
            isEmpty,
          );
        } finally {
          subscription.close();
          container.dispose();
          await chat.close();
          await medical.close();
        }
      },
    );
  }
}
