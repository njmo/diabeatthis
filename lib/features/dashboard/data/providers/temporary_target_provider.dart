import 'dart:ui';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../app/providers/app_lifecycle_state_provider.dart';
import '../../../../core/data/provider/nightscout_repository_provider.dart';
import '../../../../core/domain/model/temporary_target.dart';

part 'temporary_target_provider.g.dart';

bool isActive(TemporaryTarget t) =>
    DateTime.now().isBefore(t.createdAt.add(Duration(minutes: t.duration)));

@Riverpod(keepAlive: false)
Stream<TemporaryTarget> temporaryTargetStream(Ref ref) async* {
  final appLifecycleState = ref.watch(appLifecycleProvider);
  if (appLifecycleState != AppLifecycleState.resumed) {
    return;
  }

  var last = await ref.read(temporaryTargetProvider.future);
  var wasActive = isActive(last);
  yield last;

  while (ref.read(appLifecycleProvider) == AppLifecycleState.resumed) {
    try {
      final current = await ref.read(temporaryTargetProvider.future);

      final entryChanged = current.createdAt != last.createdAt;
      final durationChanged = current.duration != last.duration;

      final nowActive = isActive(current);
      final expiredNow =
          wasActive && !nowActive;

      if (entryChanged || durationChanged || expiredNow) {
        last = current;
        wasActive = nowActive;

        // if(expiredNow) powiadom ze sie zakonczyl

        yield current;
      } else {
        wasActive = nowActive;
      }
    } catch (_) {}

    await Future.delayed(const Duration(seconds: 5));
  }
}
