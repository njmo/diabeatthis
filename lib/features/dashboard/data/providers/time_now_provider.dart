import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'time_now_provider.g.dart';

@riverpod
Stream<DateTime> timeNow(Ref ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now());
}