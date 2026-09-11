import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/event/model/foreground_event.dart';
import 'package:diabeatthis/foreground/providers/latest_bolus_wizard_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

BolusWizard wizardAt(DateTime timestamp) => BolusWizard(
  nightscoutObjectId: null,
  createdAt: timestamp,
  date: timestamp,
  glucose: 120,
  units: 'mg/dl',
  notes: null,
  calculatorResult: null,
);

void main() {
  test('consuming a wizard empties the cache and allows a new wizard', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final events = <ForegroundEvent>[];
    final dispatcher = TreatmentEventDispatcher();
    final wizard = wizardAt(DateTime(2026, 9, 11, 12));
    void dispatch(BolusWizard value) => dispatcher.dispatch(
      container: container,
      emitEvent: events.add,
      treatment: value,
    );

    dispatch(wizard);
    expect(container.read(latestBolusWizardProvider), wizard);
    expect(events, hasLength(1));
    consumeBolusWizard(container, wizard);
    expect(container.read(latestBolusWizardProvider), isNull);

    final next = wizardAt(wizard.createdAt.add(const Duration(minutes: 1)));
    dispatch(next);
    expect(container.read(latestBolusWizardProvider), next);
    expect(events, hasLength(2));
  });

  test('consuming an older wizard preserves a newer cached wizard', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final earlier = wizardAt(DateTime(2026, 9, 11, 12));
    final later = wizardAt(earlier.createdAt.add(const Duration(minutes: 1)));
    container.read(latestBolusWizardProvider.notifier).update(later);
    consumeBolusWizard(container, earlier);
    expect(container.read(latestBolusWizardProvider), later);
  });
}
