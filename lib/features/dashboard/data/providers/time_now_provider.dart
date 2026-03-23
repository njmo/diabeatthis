import 'dart:async';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_now_provider.g.dart';

@riverpod
Stream<DateTime> timeNow(Ref ref) async* {
  yield clock.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => clock.now());
}