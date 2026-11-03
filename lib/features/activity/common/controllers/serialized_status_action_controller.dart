import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Shared action lifecycle for activity history and dashboard status controls.
abstract class SerializedStatusActionController
    extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<T> execute<T>(Future<T> Function() action) async {
    if (state.isLoading) throw StateError('A status action is already running');
    state = const AsyncLoading();
    try {
      final result = await action();
      if (ref.mounted) state = const AsyncData(null);
      return result;
    } catch (error, stack) {
      if (ref.mounted) state = AsyncError(error, stack);
      rethrow;
    }
  }
}
