import 'package:diabeatthis/common/treatments/calculator_submission.dart';
import 'package:diabeatthis/core/data_sources/nightscout/dto/bolus_wizard_dto.dart';
import 'package:diabeatthis/core/data_sources/nightscout/mappers/bolus_wizard_mapper.dart';
import 'package:diabeatthis/core/domain/model/bolus_wizard.dart';
import 'package:diabeatthis/core/domain/model/manual_bolus.dart';
import 'package:diabeatthis/foreground/providers/calculator_submissions_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final localWizard = BolusWizardDto.fromJson({
    '_id': 'wizard',
    'created_at': '2026-11-02T15:15:13.766Z',
    'glucose': 192,
    'bolusCalculatorResult': {'carbs': 48, 'totalInsulin': 43.8},
  }).toDomain(remoteSource: 'https://example.test');
  final utcWizard = localWizard.copyWith(
    createdAt: localWizard.createdAt.toUtc(),
  );

  for (final first in [localWizard, utcWizard]) {
    final other = first.createdAt.isUtc ? localWizard : utcWizard;
    test(
      'same instant in another zone updates one cached submission (${first.createdAt.isUtc})',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);
        final cache = container.read(calculatorSubmissionsProvider.notifier);
        cache.record(first);
        cache.record(other);
        expect(cache.records.whereType<BolusWizard>(), hasLength(1));
        expect(container.read(calculatorSubmissionsProvider), hasLength(1));

        cache.record(
          first.copyWith(
            calculatorResult: first.calculatorResult!.copyWith(carbs: 50),
          ),
        );
        expect(container.read(calculatorSubmissionsProvider).single.carbs, 50);
        expect(cache.records.whereType<BolusWizard>(), hasLength(1));
      },
    );
  }

  test(
    'cross-zone delivery invalidation revokes the existing confirmation',
    () {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final cache = container.read(calculatorSubmissionsProvider.notifier);
      final delivery = ManualBolus(
        externalId: 'delivery',
        createdAt: utcWizard.createdAt.add(const Duration(milliseconds: 2398)),
        insulin: 3,
      );
      cache.record(localWizard);
      cache.record(delivery);
      cache.record(delivery.copyWith(createdAt: delivery.createdAt.toLocal()));
      expect(cache.records.whereType<ManualBolus>(), hasLength(1));
      expect(
        container.read(calculatorSubmissionsProvider).single.status,
        CalculatorSubmissionStatus.deliveryConfirmed,
      );

      cache.record(delivery.copyWith(isValid: false));
      expect(cache.records.whereType<ManualBolus>(), hasLength(1));
      expect(
        container.read(calculatorSubmissionsProvider).single.status,
        CalculatorSubmissionStatus.awaitingDeliveryConfirmation,
      );
    },
  );

  test('cross-zone calculator invalidation updates the same submission', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cache = container.read(calculatorSubmissionsProvider.notifier);
    cache.record(localWizard);
    cache.record(utcWizard.copyWith(isValid: false));
    expect(container.read(calculatorSubmissionsProvider), hasLength(1));
    expect(
      container.read(calculatorSubmissionsProvider).single.isValid,
      isFalse,
    );
  });

  test('same-instant normalization does not bypass identity conflicts', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final cache = container.read(calculatorSubmissionsProvider.notifier);
    cache.record(localWizard);
    expect(
      cache.record(utcWizard.copyWith(nightscoutObjectId: 'conflict')),
      isEmpty,
    );
    expect(
      cache.record(
        utcWizard.copyWith(
          createdAt: utcWizard.createdAt.add(const Duration(seconds: 1)),
        ),
      ),
      isEmpty,
    );
    expect(container.read(calculatorSubmissionsProvider), hasLength(1));
    expect(
      container
          .read(calculatorSubmissionsProvider)
          .single
          .wizard
          .nightscoutObjectId,
      'wizard',
    );
  });
}
