import 'dart:async';
import 'dart:ui';

import 'package:clock/clock.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';

part 'time_now_provider.g.dart';

@riverpod
Stream<DateTime> timeNow(Ref ref) async* {
  final lifecycle = ref.watch(appLifecycleProvider);

  if (lifecycle != AppLifecycleState.resumed) {
    return;
  }

  yield clock.now();
  yield* Stream.periodic(
    const Duration(minutes: 1),
        (_) => clock.now(),
  );
}