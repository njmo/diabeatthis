import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/core/domain/model/treatment_base.dart';
import 'package:diabeatthis/foreground/event/internal/calculator_submission_changed_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_available_event.dart';
import 'package:diabeatthis/foreground/event/internal/treatment_event_dispatcher.dart';
import 'package:diabeatthis/foreground/event/model/foreground_event.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final wizard = BolusWizardDto.fromJson({
    '_id': 'wizard',
    'created_at': '2026-11-02T14:05:49.906Z',
    'glucose': 135,
    'bolusCalculatorResult': {'carbs': 48, 'totalInsulin': 44.7},
  }).toDomain(remoteSource: 'https://example.test');
  final delivery = ManualBolus(
    externalId: 'delivery',
    createdAt: wizard.createdAt.add(const Duration(milliseconds: 830)),
    insulin: 3,
  );
  late ProviderContainer container;
  late CalculatorSubmissions cache;

  setUp(() {
    container = ProviderContainer();
    cache = container.read(calculatorSubmissionsProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('calculator alone awaits independent delivery confirmation', () {
    final submission = cache.record(wizard).single;
    expect(submission.key, wizard.createdAt);
    expect(submission.carbs, 48);
    expect(submission.recommendedInsulin, 44.7);
    expect(submission.deliveredInsulin, isNull);
    expect(
      submission.status,
      CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
    );
  });

  test('both delivery orders produce one submission with actual insulin', () {
    for (final input in <List<Treatment>>[
      [wizard, delivery],
      [delivery, wizard],
    ]) {
      final local = ProviderContainer();
      final notifier = local.read(calculatorSubmissionsProvider.notifier);
      for (final record in input) {
        notifier.record(record);
      }
      final submission = local.read(calculatorSubmissionsProvider).single;
      expect(submission.status, CalculatorSubmissionStatus.deliveryConfirmed);
      expect(submission.deliveredInsulin, 3);
      expect(submission.recommendedInsulin, 44.7);
      expect(submission.wizard, wizard);
      expect(submission.delivery, delivery);
      local.dispose();
    }
  });

  test('replayed records do not emit redundant submission changes', () {
    cache.record(wizard);
    cache.record(delivery);
    expect(cache.record(wizard), isEmpty);
    expect(cache.record(delivery), isEmpty);
    expect(cache.records, hasLength(2));
  });

  test(
    'invalidated delivery revokes confirmation and stays in live history',
    () {
      cache.record(wizard);
      cache.record(delivery);
      final invalid = delivery.copyWith(isValid: false);
      final submission = cache.record(invalid).single;
      expect(
        submission.status,
        CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
      );
      expect(submission.deliveredInsulin, isNull);
      expect(cache.records, contains(invalid));
    },
  );

  test('invalidated calculator cannot retain a confirmed submission', () {
    cache.record(wizard);
    cache.record(delivery);
    final submission = cache.record(wizard.copyWith(isValid: false)).single;
    expect(submission.isValid, isFalse);
    expect(submission.deliveredInsulin, isNull);
    expect(
      submission.status,
      CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
    );
  });

  test('competing calculator revokes ambiguous delivery confirmation', () {
    cache.record(wizard);
    cache.record(delivery);
    final changes = cache.record(
      wizard.copyWith(
        createdAt: wizard.createdAt.add(const Duration(milliseconds: 100)),
        nightscoutObjectId: 'other',
      ),
    );
    expect(changes, hasLength(2));
    expect(changes.every((item) => item.delivery == null), isTrue);
  });

  test('cloud identity survives local enrichment and rejects conflicts', () {
    cache.record(wizard);
    cache.record(wizard.copyWith(nightscoutObjectId: null, remoteSource: null));
    expect(
      container
          .read(calculatorSubmissionsProvider)
          .single
          .wizard
          .nightscoutObjectId,
      'wizard',
    );
    expect(
      cache.record(wizard.copyWith(nightscoutObjectId: 'conflict')),
      isEmpty,
    );
    expect(
      container
          .read(calculatorSubmissionsProvider)
          .single
          .wizard
          .nightscoutObjectId,
      'wizard',
    );
  });

  test('partial identities never invent a remote source and ID pairing', () {
    cache.record(wizard.copyWith(nightscoutObjectId: null));
    cache.record(wizard.copyWith(remoteSource: null));
    final merged = container.read(calculatorSubmissionsProvider).single.wizard;
    expect(merged.nightscoutObjectId, wizard.nightscoutObjectId);
    expect(merged.remoteSource, isNull);
  });

  test('known identities cannot move timestamp or change local ID', () {
    cache.record(wizard.copyWith(localId: 'local'));
    expect(cache.record(wizard.copyWith(localId: 'other')), isEmpty);
    expect(
      cache.record(
        wizard.copyWith(
          createdAt: wizard.createdAt.add(const Duration(seconds: 2)),
        ),
      ),
      isEmpty,
    );
    expect(container.read(calculatorSubmissionsProvider), hasLength(1));
  });

  test(
    'unidentified conflicting values cannot overwrite identified wizard',
    () {
      cache.record(wizard);
      expect(
        cache.record(
          wizard.copyWith(
            nightscoutObjectId: null,
            remoteSource: null,
            calculatorResult: wizard.calculatorResult!.copyWith(carbs: 20),
          ),
        ),
        isEmpty,
      );
      expect(container.read(calculatorSubmissionsProvider).single.carbs, 48);
    },
  );

  test('invalid recorded amounts never report delivery confirmation', () {
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      final submission = CalculatorSubmission(
        wizard: wizard,
        delivery: delivery.copyWith(insulin: amount),
      );
      expect(
        submission.status,
        CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
      );
      expect(submission.deliveredInsulin, isNull);
    }
  });

  test('dispatcher emits normalized changes alongside legacy availability', () {
    final events = <ForegroundEvent>[];
    final dispatcher = TreatmentEventDispatcher();
    for (final item in <Treatment>[
      wizard,
      delivery,
      delivery.copyWith(isValid: false),
    ]) {
      dispatcher.dispatch(
        container: container,
        emitEvent: events.add,
        treatment: item,
      );
    }
    expect(
      events.whereType<TreatmentAvailableEvent<BolusWizard>>(),
      hasLength(1),
    );
    expect(
      events.whereType<TreatmentAvailableEvent<ManualBolus>>(),
      hasLength(1),
    );
    final changes = events
        .whereType<CalculatorSubmissionChangedEvent>()
        .toList();
    expect(changes.map((event) => event.submission.status), [
      CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
      CalculatorSubmissionStatus.deliveryConfirmed,
      CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
    ]);
  });
}
