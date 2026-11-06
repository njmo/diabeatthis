import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/drift/providers/database_provider.dart';
import '../../l10n/language.dart';
import '../family_mirror_status.dart';
import '../request_family_mirror_sync.dart';

final familyMirrorStatusProvider =
    StreamProvider.autoDispose<FamilyMirrorStatus>((ref) async* {
      final db = ref.watch(databaseProvider);
      yield await readFamilyMirrorStatus(db, DateTime.now());
      await for (final _ in Stream.periodic(const Duration(seconds: 2))) {
        yield await readFamilyMirrorStatus(db, DateTime.now());
      }
    });

class FamilyMirrorStatusBanner extends ConsumerWidget {
  const FamilyMirrorStatusBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(familyMirrorStatusProvider).asData?.value ??
        FamilyMirrorStatus.hidden;
    if (status == FamilyMirrorStatus.hidden) return const SizedBox.shrink();
    final text = switch (status) {
      FamilyMirrorStatus.syncing => context.lang.familyMirrorSyncing,
      FamilyMirrorStatus.waiting => context.lang.familyMirrorWaiting,
      FamilyMirrorStatus.failed => context.lang.familyMirrorRetry,
      FamilyMirrorStatus.blocked => context.lang.familyMirrorBlocked,
      _ => context.lang.familyMirrorSynchronized,
    };
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHigh,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            if (status == FamilyMirrorStatus.syncing)
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(
                status == FamilyMirrorStatus.synchronized
                    ? Icons.cloud_done_outlined
                    : Icons.cloud_queue,
                size: 20,
              ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(text, style: Theme.of(context).textTheme.bodySmall),
            ),
            if (status == FamilyMirrorStatus.failed ||
                status == FamilyMirrorStatus.waiting)
              IconButton(
                onPressed: () =>
                    requestFamilyMirrorSync(ref.read(databaseProvider)),
                tooltip: context.lang.familySyncNow,
                icon: const Icon(Icons.refresh),
              ),
          ],
        ),
      ),
    );
  }
}
