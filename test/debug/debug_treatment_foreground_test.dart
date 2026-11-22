import 'package:clock/clock.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/correction_bolus.dart';
import 'package:diabeatthis/core/domain/model/extended_carb.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treat.dart';
import 'package:diabeatthis/debug/debug_treatment_event.dart';
import 'package:diabeatthis/debug/debug_treatment_foreground.dart';
import 'package:diabeatthis/foreground/event/external/external_event_handler.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../foreground/utils/fake_runtime_harness.dart';

void main() {
  test('simulator app events become ordinary foreground treatments', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final harness = FakeRuntimeHarness(container: container);
    final handler = ExternalEventHandler(
      harness.runtimeContext,
      handleAdditionalEvent: handleDebugTreatmentEvent,
    );

    final timestamp = DateTime(2026, 11, 22, 10);
    void send(DebugTreatmentEvent event, {int secondsLater = 0}) {
      withClock(
        Clock.fixed(timestamp.add(Duration(seconds: secondsLater))),
        () => handler.handle(event.toExternalAppEventJson()),
      );
    }

    send(const DebugTreatmentEvent(kind: DebugTreatmentKind.carbs, carbs: 36));
    send(
      const DebugTreatmentEvent(
        kind: DebugTreatmentKind.calculator,
        insulin: 2.5,
        carbs: 36,
      ),
      secondsLater: 1,
    );
    send(
      const DebugTreatmentEvent(
        kind: DebugTreatmentKind.manualBolus,
        insulin: 2.5,
      ),
      secondsLater: 2,
    );
    send(
      const DebugTreatmentEvent(
        kind: DebugTreatmentKind.correctionBolus,
        insulin: 0.5,
      ),
      secondsLater: 3,
    );
    send(
      const DebugTreatmentEvent(
        kind: DebugTreatmentKind.extendedCarbs,
        carbs: 15,
        minutes: 90,
      ),
      secondsLater: 4,
    );
    send(const DebugTreatmentEvent(kind: DebugTreatmentKind.extendedCarbs));

    final events = harness.emittedEvents;
    expect(
      events.whereType<TreatmentAvailableEvent<Treat>>().single.data.carbs,
      36,
    );
    final wizard = events
        .whereType<TreatmentAvailableEvent<BolusWizard>>()
        .single
        .data;
    expect(wizard.createdAt, timestamp.add(const Duration(seconds: 1)));
    expect(wizard.carbs, 36);
    expect(wizard.insulin, 2.5);
    expect(
      events
          .whereType<TreatmentAvailableEvent<ManualBolus>>()
          .single
          .data
          .insulin,
      2.5,
    );
    expect(
      events
          .whereType<TreatmentAvailableEvent<CorrectionBolus>>()
          .single
          .data
          .insulin,
      0.5,
    );
    final extended = events
        .whereType<TreatmentAvailableEvent<ExtendedCarb>>()
        .single
        .data;
    expect(extended.carbs, 15);
    expect(extended.duration, const Duration(minutes: 90).inMilliseconds);
    expect(
      container.read(calculatorSubmissionsProvider).single.deliveredInsulin,
      2.5,
    );
  });

  test(
    'simulator input rejects invalid quantities and accepts decimal commas',
    () {
      expect(
        DebugTreatmentEvent.tryParse(
          DebugTreatmentKind.manualBolus,
          insulin: 'NaN',
        ),
        isNull,
      );
      expect(
        DebugTreatmentEvent.tryParse(
          DebugTreatmentKind.extendedCarbs,
          carbs: '10',
          minutes: '-1',
        ),
        isNull,
      );
      expect(
        DebugTreatmentEvent.tryParse(
          DebugTreatmentKind.calculator,
          insulin: '0',
          carbs: '20',
        )?.insulin,
        0,
      );
      expect(
        DebugTreatmentEvent.tryParse(
          DebugTreatmentKind.manualBolus,
          insulin: '1,25',
        )?.insulin,
        1.25,
      );
    },
  );
}
