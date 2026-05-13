import 'package:circular_buffer/circular_buffer.dart';
import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/domain/model/glucose.dart';

part 'blood_sugar_readings_list_provider.g.dart';

@Riverpod(keepAlive: true)
class BloodSugarReadingsListNotifier extends _$BloodSugarReadingsListNotifier {
  static const _maxSize = 10;
  final CircularBuffer<Glucose> _buffer = CircularBuffer<Glucose>(_maxSize);

  @override
  AsyncValue<List<Glucose>> build() {
    return const AsyncValue.loading();
  }

  void update(Glucose glucose) {
    if (_buffer.any((reading) => reading.date.isAtSameMomentAs(glucose.date))) {
      return;
    }

    _buffer.addHead(glucose);

    if (_buffer.isFilled) {
      state = AsyncData(List.unmodifiable(_buffer.toList()));
    } else {
      state = const AsyncLoading();
    }
  }

  bool syncNeeded() {
    final last = _buffer.firstOrNull;
    return _buffer.isUnfilled ||
        last == null ||
        last.date.isBefore(clock.now().subtract(const Duration(minutes: 5)));
  }
}
