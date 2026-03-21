import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../core/domain/model/glucose.dart';

part 'blood_sugar_value_provider.g.dart';

@Riverpod(keepAlive: true)
class BloodSugarValueNotifier extends _$BloodSugarValueNotifier {
  Timer? _expiryTimer;

  @override
  Glucose? build() {
    ref.onDispose(() {
      _expiryTimer?.cancel();
    });

    return null;
  }

  void update(Glucose value) {
    final now = DateTime.now();
    final readingAge = now.difference(value.date);

    if (readingAge.inMinutes >= 6) {
      state = null;
      return;
    }

    state = value;

    _expiryTimer?.cancel();

    final remaining = const Duration(minutes: 6) - readingAge;

    _expiryTimer = Timer(remaining, () {
      state = null;
    });
  }
}