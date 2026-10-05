import 'dart:async';

import 'package:diabeatthis/common/platform/aaps_launcher.dart';
import 'package:diabeatthis/core/domain/model/low_treatment_context.dart';
import 'package:diabeatthis/features/low_treatment/data/models/low_treatment_sheet_state.dart';
import 'package:diabeatthis/features/low_treatment/presentation/controllers/low_treatment_context_controller.dart';
import 'package:diabeatthis/features/low_treatment/presentation/widgets/low_treatment_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/localized_material_app.dart';

void main() {
  const saved = LowTreatmentContext(
    mealId: 42,
    source: LowTreatmentContextSource.dashboardAction,
    reason: LowTreatmentReason.carbsReq,
  );
  for (final launchResult in [
    AapsLaunchResult.opened,
    AapsLaunchResult.unavailable,
  ]) {
    testWidgets(
      'saved treatment opens AAPS; $launchResult preserves local result',
      (tester) async {
        final launcher = RecordingAapsLauncher(launchResult);
        LowTreatmentContext? result;
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              aapsLauncherProvider.overrideWithValue(launcher),
              lowTreatmentContextControllerProvider.overrideWith(
                PendingSheetController.new,
              ),
            ],
            child: localizedMaterialApp(
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () async {
                      result = await showLowTreatmentSheet(context);
                    },
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Open'));
        await tester.pump();
        expect(launcher.calls, 0);
        tester.state<NavigatorState>(find.byType(Navigator).first).pop(saved);
        await tester.pumpAndSettle();
        expect(launcher.calls, 1);
        expect(result, saved);
        expect(
          find.byType(SnackBar),
          launchResult == AapsLaunchResult.opened
              ? findsNothing
              : findsOneWidget,
        );
      },
    );
  }
  testWidgets('cancelling the sheet does not open AAPS', (tester) async {
    final launcher = RecordingAapsLauncher(AapsLaunchResult.opened);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          aapsLauncherProvider.overrideWithValue(launcher),
          lowTreatmentContextControllerProvider.overrideWith(
            PendingSheetController.new,
          ),
        ],
        child: localizedMaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showLowTreatmentSheet(context),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pump();
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(launcher.calls, 0);
  });
}

class RecordingAapsLauncher extends AapsLauncher {
  RecordingAapsLauncher(this.result);
  final AapsLaunchResult result;
  int calls = 0;
  @override
  Future<AapsLaunchResult> openAaps() async {
    calls++;
    return result;
  }
}

class PendingSheetController extends LowTreatmentContextController {
  @override
  Future<LowTreatmentSheetState> build() =>
      Completer<LowTreatmentSheetState>().future;
}
