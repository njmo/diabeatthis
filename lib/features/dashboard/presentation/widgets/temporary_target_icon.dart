import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/temporary_target_provider.dart';
import '../../data/providers/time_now_provider.dart';

class TemporaryTargetIcon extends ConsumerWidget {
  const TemporaryTargetIcon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final targetAsync = ref.watch(temporaryTargetStreamProvider);
    final nowAsync = ref.watch(timeNowProvider);

    return targetAsync.when(
      loading: () => const Text('Ładowanie...'),
      error: (e, _) => Text('Błąd: $e'),
      data: (target) {
        final now = nowAsync.when(
          data: (data) => data,
          error: (_, _) => DateTime.now(),
          loading: () => DateTime.now(),
        );
        final elapsed = now.difference(target.createdAt).inMinutes;
        final clampedElapsed = elapsed.clamp(0, target.duration);
        final expired = elapsed >= target.duration;

        if (expired) {
          return const Text('Target zakończony');
        }
        return Text(
          'Target ${target.targetTop}mg/dl aktywny przez $clampedElapsed/${target.duration} min',
        );
      },
    );
  }
}
