import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'caregiver_nightscout_snapshot.dart';

class CaregiverRefreshState {
  const CaregiverRefreshState({
    this.refreshing = false,
    this.lastSuccess,
    this.failed = false,
    this.connection,
    this.snapshot,
  });
  final bool refreshing;
  final DateTime? lastSuccess;
  final bool failed;
  final String? connection;
  final CaregiverNightscoutSnapshot? snapshot;
}

final caregiverRefreshStateProvider =
    NotifierProvider<CaregiverRefreshStateNotifier, CaregiverRefreshState>(
      CaregiverRefreshStateNotifier.new,
    );

class CaregiverRefreshStateNotifier extends Notifier<CaregiverRefreshState> {
  @override
  CaregiverRefreshState build() => const CaregiverRefreshState();
  void beginConnection(String fingerprint) {
    if (state.connection == fingerprint) return;
    state = CaregiverRefreshState(connection: fingerprint);
  }

  void started() => state = CaregiverRefreshState(
    refreshing: true,
    lastSuccess: state.lastSuccess,
    failed: state.failed,
    connection: state.connection,
    snapshot: state.snapshot,
  );
  void finished({CaregiverNightscoutSnapshot? snapshot, required bool failed}) {
    final previous = state.snapshot;
    final merged = snapshot == null
        ? previous
        : CaregiverNightscoutSnapshot(
            glucose: snapshot.glucose ?? previous?.glucose,
            deviceStatus: snapshot.deviceFetched
                ? snapshot.deviceStatus
                : snapshot.deviceStatus ?? previous?.deviceStatus,
            deviceFetched:
                snapshot.deviceFetched || previous?.deviceFetched == true,
            temporaryTarget: snapshot.targetFetched
                ? snapshot.temporaryTarget
                : previous?.temporaryTarget,
            targetFetched:
                snapshot.targetFetched || previous?.targetFetched == true,
            hasFailures: failed,
          );
    state = CaregiverRefreshState(
      connection: state.connection,
      snapshot: merged,
      lastSuccess: snapshot?.hasData == true
          ? DateTime.now()
          : state.lastSuccess,
      failed: failed,
    );
  }
}
