import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/glucose.dart';

part 'blood_sugar_readings_list_provider.g.dart';

@Riverpod(keepAlive: true)
class BloodSugarReadingsListNotifier extends _$BloodSugarReadingsListNotifier {
  static const _maxSize = 10;
  final List<Glucose> _readings = [];

  @override
  AsyncValue<List<Glucose>> build() {
    return const AsyncData([]);
  }

  void update(Glucose glucose) {
    if (_readings.isEmpty) return;

    replaceAll([..._readings, glucose]);
  }

  void replaceAll(Iterable<Glucose> readings) {
    final byTimestamp = <int, Glucose>{};
    for (final reading in readings) {
      byTimestamp[reading.date.millisecondsSinceEpoch] = reading;
    }

    _readings
      ..clear()
      ..addAll(byTimestamp.values)
      ..sort((a, b) => b.date.compareTo(a.date));

    if (_readings.length > _maxSize) {
      _readings.removeRange(_maxSize, _readings.length);
    }

    state = AsyncData(List.unmodifiable(_readings));
  }

  bool syncNeeded() {
    final last = _readings.firstOrNull;
    return _readings.length < _maxSize ||
        last == null ||
        last.date.isBefore(clock.now().subtract(const Duration(minutes: 5)));
  }
}
