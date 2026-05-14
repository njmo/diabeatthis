import 'package:diabeatthis/core/domain/model/glucose.dart';
import 'package:diabeatthis/features/dashboard/data/providers/blood_sugar_readings_list_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('does not initialize chart history from a single live reading', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(
      container
          .read(bloodSugarReadingsListProvider)
          .maybeWhen(data: (readings) => readings, orElse: () => null),
      isEmpty,
    );

    container
        .read(bloodSugarReadingsListProvider.notifier)
        .update(
          Glucose(
            id: 1,
            externalId: null,
            source: GlucoseSource.cloud,
            date: DateTime.fromMillisecondsSinceEpoch(1000),
            sgv: 120,
            direction: 'Flat',
          ),
        );

    final readings = container
        .read(bloodSugarReadingsListProvider)
        .maybeWhen(data: (readings) => readings, orElse: () => null);

    expect(readings, isEmpty);
  });

  test('replaces readings in newest first order without duplicates', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(bloodSugarReadingsListProvider.notifier);

    notifier.replaceAll([
      Glucose(
        id: 1,
        externalId: null,
        source: GlucoseSource.cloud,
        date: DateTime.fromMillisecondsSinceEpoch(1000),
        sgv: 110,
        direction: 'Flat',
      ),
      Glucose(
        id: 2,
        externalId: null,
        source: GlucoseSource.cloud,
        date: DateTime.fromMillisecondsSinceEpoch(3000),
        sgv: 130,
        direction: 'SingleUp',
      ),
      Glucose(
        id: 3,
        externalId: null,
        source: GlucoseSource.cloud,
        date: DateTime.fromMillisecondsSinceEpoch(2000),
        sgv: 120,
        direction: 'Flat',
      ),
      Glucose(
        id: 4,
        externalId: null,
        source: GlucoseSource.cloud,
        date: DateTime.fromMillisecondsSinceEpoch(2000),
        sgv: 121,
        direction: 'FortyFiveUp',
      ),
    ]);

    final readings = container
        .read(bloodSugarReadingsListProvider)
        .maybeWhen(data: (readings) => readings, orElse: () => null);

    expect(readings, hasLength(3));
    expect(readings!.map((reading) => reading.sgv), [130, 121, 110]);
  });
}
