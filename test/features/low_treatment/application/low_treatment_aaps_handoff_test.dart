import 'package:diabeatthis/common/handoff/controllers/handoff_controller.dart';
import 'package:diabeatthis/common/handoff/handoff_gateway.dart';
import 'package:diabeatthis/common/handoff/handoff_instruction.dart';
import 'package:diabeatthis/common/l10n/language.dart';
import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/features/low_treatment/application/confirm_low_treatment_aaps_use_case.dart';
import 'package:diabeatthis/features/low_treatment/application/open_low_treatment_aaps_use_case.dart';
import 'package:diabeatthis/features/low_treatment/domain/models/recorded_low_treatment.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final strings = lookupAppLocalizations(const Locale('pl'));

  test(
    'shows persisted carbs and foreground confirmation targets the same session',
    () async {
      final gateway = LowTreatmentGatewayFake();
      final controller = HandoffController(gateway);
      final launcher = LowTreatmentLauncherFake();
      final open = OpenLowTreatmentAapsUseCase(
        loadRecorded: (id) async => RecordedLowTreatment(
          mealId: id,
          eatenAt: DateTime(2026),
          netCarbsGrams: 13,
          suggestedCarbs: 20,
        ),
        handoff: controller,
        launcher: launcher,
      );
      expect(await open(7, strings), AapsLaunchResult.opened);
      expect(gateway.instruction!.steps.single.value, '13 g');
      expect(gateway.instruction!.title, strings.lowTreatmentRecordTitle);
      expect(launcher.calls, 0);
      await ConfirmLowTreatmentAapsUseCase(controller)(7);
      expect(gateway.updatedSession, gateway.openedSession);
      expect(gateway.completed, [true]);
    },
  );

  test('PiP rejection falls back to opening AAPS once', () async {
    final gateway = LowTreatmentGatewayFake()..opens = false;
    final launcher = LowTreatmentLauncherFake();
    final open = OpenLowTreatmentAapsUseCase(
      loadRecorded: (id) async => RecordedLowTreatment(
        mealId: id,
        eatenAt: DateTime(2026),
        netCarbsGrams: 12,
      ),
      handoff: HandoffController(gateway),
      launcher: launcher,
    );
    expect(await open(7, strings), AapsLaunchResult.opened);
    expect(launcher.calls, 1);
  });

  for (final carbs in [null, 0.0, double.nan]) {
    test(
      'missing or invalid actual carbs do not create a misleading PiP: $carbs',
      () async {
        final gateway = LowTreatmentGatewayFake();
        final launcher = LowTreatmentLauncherFake();
        final open = OpenLowTreatmentAapsUseCase(
          loadRecorded: (id) async => RecordedLowTreatment(
            mealId: id,
            eatenAt: DateTime(2026),
            netCarbsGrams: carbs,
          ),
          handoff: HandoffController(gateway),
          launcher: launcher,
        );
        await open(7, strings);
        expect(gateway.instruction, isNull);
        expect(launcher.calls, 1);
      },
    );
  }
}

class LowTreatmentGatewayFake implements HandoffGateway {
  bool opens = true;
  HandoffInstruction? instruction;
  String? openedSession;
  String? updatedSession;
  List<bool>? completed;
  @override
  bool get isSupported => true;
  @override
  Future<bool> openInstruction({
    required HandoffInstruction instruction,
    required String packageName,
    String? sessionId,
  }) async {
    this.instruction = instruction;
    openedSession = sessionId;
    return opens;
  }

  @override
  Future<void> updateRows(String sessionId, List<bool> completed) async {
    updatedSession = sessionId;
    this.completed = completed;
  }

  @override
  Future<void> dismiss(String sessionId) async {}
}

class LowTreatmentLauncherFake extends AapsLauncher {
  int calls = 0;
  @override
  Future<AapsLaunchResult> openAaps() async {
    calls++;
    return AapsLaunchResult.opened;
  }
}
