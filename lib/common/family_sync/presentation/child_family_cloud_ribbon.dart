import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/database_impl.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../l10n/language.dart';
import '../../presentation/dashboard/family_sync_ribbon.dart';
import '../family_mirror_status.dart';

class FamilyCloudState {
  const FamilyCloudState({required this.enabled, required this.status});
  final bool enabled;
  final FamilyMirrorStatus status;
}

Future<FamilyCloudState> readChildFamilyCloudState(DatabaseImpl db) async {
  final row = await db
      .customSelect(
        "SELECT enabled,last_error,(SELECT CASE WHEN c.owner_uid=i.owner_uid THEN c.state ELSE 'connecting' END FROM family_cloud_connection c WHERE c.singleton=1) AS connection_state FROM family_sync_identity i WHERE singleton=1",
      )
      .getSingle();
  return FamilyCloudState(
    enabled: row.read<int>('enabled') == 1,
    status:
        row.readNullable<String>('connection_state') == 'disconnected' ||
            row.readNullable<String>('last_error') != null
        ? FamilyMirrorStatus.failed
        : row.readNullable<String>('connection_state') != 'connected'
        ? FamilyMirrorStatus.syncing
        : await readFamilyMirrorStatus(db, DateTime.now()),
  );
}

/// This clock only paints local metadata. It never performs Firebase requests.
final childFamilyCloudStateProvider =
    StreamProvider.autoDispose<FamilyCloudState>((ref) async* {
      final db = ref.watch(databaseProvider);
      yield await readChildFamilyCloudState(db);
      yield* Stream.periodic(
        const Duration(seconds: 2),
      ).asyncMap((_) => readChildFamilyCloudState(db));
    });

class ChildFamilyCloudRibbon extends ConsumerWidget {
  const ChildFamilyCloudRibbon({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(childFamilyCloudStateProvider).asData?.value;
    if (state?.enabled != true) return const SizedBox.shrink();
    return FamilySyncRibbon(
      busy: [
        FamilyMirrorStatus.syncing,
        FamilyMirrorStatus.waiting,
      ].contains(state!.status),
      failed: [
        FamilyMirrorStatus.failed,
        FamilyMirrorStatus.blocked,
      ].contains(state.status),
      ready: true,
      failureIcon: Icons.person_off_outlined,
      syncIcon: Icons.cloud_upload_outlined,
      busyLabel: context.lang.childCloudSyncing,
      readyLabel: context.lang.childCloudSynced,
      failureLabel: context.lang.childCloudUnavailable,
    );
  }
}
