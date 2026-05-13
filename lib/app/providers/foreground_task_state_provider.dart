import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'foreground_task_state_provider.g.dart';

class ForegroundTaskUiState {
  const ForegroundTaskUiState({this.alive = false});

  final bool alive;

  ForegroundTaskUiState copyWith({bool? alive}) {
    return ForegroundTaskUiState(alive: alive ?? this.alive);
  }
}

@Riverpod(keepAlive: true)
class ForegroundTaskState extends _$ForegroundTaskState {
  Completer<void>? _aliveCompleter;

  @override
  ForegroundTaskUiState build() {
    return const ForegroundTaskUiState();
  }

  void setAlive(bool isAlive) {
    state = state.copyWith(alive: isAlive);

    if (isAlive) {
      _aliveCompleter?.complete();
      _aliveCompleter = null;
    } else {
      _aliveCompleter = Completer<void>();
    }
  }

  Future<void> waitForAlive({Duration timeout = const Duration(seconds: 10)}) {
    if (state.alive) return Future.value();

    _aliveCompleter ??= Completer<void>();
    return _aliveCompleter!.future.timeout(timeout);
  }

  Future<void> waitForNextAlive(
    Future<void> Function() startForeground, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    setAlive(false);
    await startForeground();
    await waitForAlive(timeout: timeout);
  }
}
