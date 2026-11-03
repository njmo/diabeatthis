import 'dart:ui';

import 'package:diabeatthis/common/handoff/controllers/handoff_controller.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/features/low_treatment/application/open_low_treatment_aaps_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_aaps_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/regression/scripted_handoff_gateway.dart';
import '../../../helpers/regression/scripted_read.dart';
import '../low_treatment_aaps_launch_test.dart' show RecordingAapsLauncher;

void main() {
  setUp(() => LanguageStrings.setSelectedLocale(const Locale('en')));
  tearDown(() => LanguageStrings.setSelectedLocale(const Locale('pl')));
  for (final supported in [true, false]) {
    test(
      'handoff uses persisted consumption, never suggested carbohydrates; supported=$supported',
      () async {
        final reads = ScriptedRead<RecordedLowTreatment?>(
          'recorded low treatment',
          [
            (
              arguments: [42],
              respond: () => RecordedLowTreatment(
                mealId: 42,
                eatenAt: DateTime.utc(2026, 11, 1),
                netCarbsGrams: 13,
                suggestedCarbs: 30,
              ),
            ),
          ],
        );
        final openings = ScriptedRead<bool>(
          'handoff',
          supported
              ? [
                  (
                    arguments: [
                      'info.nightscout.androidaps',
                      'lowTreatment:42',
                      ['13 g'],
                      ['lowTreatment.carbs'],
                    ],
                    respond: () => true,
                  ),
                ]
              : [],
        );
        final launcher = RecordingAapsLauncher(AapsLaunchResult.opened);
        final controller = LowTreatmentAapsController(
          OpenLowTreatmentAapsUseCase(
            loadRecorded: (id) => reads([id]),
            handoff: HandoffController(
              ScriptedHandoffGateway(
                openings: openings,
                isSupported: supported,
              ),
            ),
            launcher: launcher,
          ),
        );
        expect(await controller.open(42, lang), AapsLaunchResult.opened);
        expect(launcher.calls, supported ? 0 : 1);
        // An unsupported platform may return before loading local nutrition.
        // If it does load, the scripted ID and response still apply.
        if (supported) reads.verifyComplete();
        expect(reads.unexpectedCalls, 0);
        openings.verifyComplete();
      },
    );
  }
  test(
    'missing recorded nutrition cannot invent an instruction from a suggestion',
    () async {
      final reads = ScriptedRead<RecordedLowTreatment?>(
        'recorded low treatment',
        [
          (
            arguments: [42],
            respond: () => RecordedLowTreatment(
              mealId: 42,
              eatenAt: DateTime.utc(2026, 11, 1),
              netCarbsGrams: null,
              suggestedCarbs: 30,
            ),
          ),
        ],
      );
      final openings = ScriptedRead<bool>('handoff', []);
      final launcher = RecordingAapsLauncher(AapsLaunchResult.unavailable);
      final controller = LowTreatmentAapsController(
        OpenLowTreatmentAapsUseCase(
          loadRecorded: (id) => reads([id]),
          handoff: HandoffController(
            ScriptedHandoffGateway(openings: openings),
          ),
          launcher: launcher,
        ),
      );
      expect(await controller.open(42, lang), AapsLaunchResult.unavailable);
      expect(launcher.calls, 1);
      reads.verifyComplete();
      openings.verifyComplete();
    },
  );
}
