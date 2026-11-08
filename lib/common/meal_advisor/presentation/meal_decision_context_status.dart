import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:intl/intl.dart';

import '../../l10n/language.dart';
import '../../widgets/inline_status_notice.dart';

/// Synchronization time is separate from the ages of the clinical readings.
class MealDecisionContextStatus extends HookWidget {
  const MealDecisionContextStatus({
    super.key,
    required this.syncedAt,
    this.glucoseAt,
    this.iobAt,
    this.cobAt,
    this.notices = const [],
    this.referenceTime,
    this.syncFailed = false,
    this.syncing = false,
  });
  final DateTime? syncedAt, glucoseAt, iobAt, cobAt;
  final bool syncFailed, syncing;
  final List<Widget> notices;

  /// Fixed reference for explicitly simulated snapshots; real data use the clock.
  final DateTime? referenceTime;

  @override
  Widget build(BuildContext context) {
    final tick = useState(clock.now());
    useEffect(() {
      if (referenceTime != null) return null;
      final timer = Timer.periodic(
        const Duration(minutes: 1),
        (_) => tick.value = clock.now(),
      );
      return timer.cancel;
    }, [referenceTime]);
    final now = referenceTime ?? clock.now();
    final dates = <String, DateTime?>{
      context.lang.mealDecisionDemoGlucose: glucoseAt,
      context.lang.dashboardIobLabel: iobAt,
      context.lang.dashboardCobLabel: cobAt,
    };
    final stale = dates.entries
        .where(
          (entry) =>
              entry.value != null &&
              now.difference(entry.value!) > const Duration(minutes: 5),
        )
        .map((entry) => entry.key)
        .toList();
    final missing = dates.entries
        .where((entry) => entry.value == null || entry.value!.isAfter(now))
        .map((entry) => entry.key)
        .toList();
    final localSync = syncedAt?.toLocal();
    final time = localSync == null
        ? null
        : DateUtils.isSameDay(localSync, now.toLocal())
        ? DateFormat.Hm(context.lang.localeName).format(localSync)
        : DateFormat.yMd(context.lang.localeName).add_Hm().format(localSync);
    final syncOld =
        syncedAt != null &&
        now.difference(syncedAt!) > const Duration(minutes: 5);
    final healthy =
        !syncFailed &&
        !syncing &&
        syncedAt != null &&
        !syncedAt!.isAfter(now) &&
        !syncOld &&
        stale.isEmpty &&
        missing.isEmpty;
    final color = syncFailed
        ? Theme.of(context).colorScheme.error
        : syncing
        ? Theme.of(context).colorScheme.primary
        : healthy
        ? Colors.green.shade400
        : Colors.amber.shade600;
    final icon = syncFailed
        ? Icons.error_outline
        : syncing
        ? Icons.sync
        : healthy
        ? Icons.check_circle_outline
        : stale.isNotEmpty || syncOld
        ? Icons.warning_amber_rounded
        : Icons.info_outline;
    final description = syncFailed
        ? context.lang.mealDecisionContextSyncFailed
        : syncing
        ? context.lang.mealDecisionContextSyncing
        : healthy
        ? context.lang.mealDecisionContextDataCurrent
        : context.lang.mealDecisionContextDataCheck;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .035),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Tooltip(
                message: description,
                child: Semantics(
                  label: description,
                  child: Icon(icon, size: 18, color: color),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  description,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: color),
                ),
              ),
              const SizedBox(width: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 130),
                child: Tooltip(
                  message: time == null
                      ? context.lang.mealDecisionContextNoSync
                      : context.lang.mealDecisionContextLastSync(time),
                  child: Text(
                    time ?? context.lang.mealDecisionContextNoSync,
                    textAlign: TextAlign.end,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ),
            ],
          ),
          if (stale.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              context.lang.mealDecisionContextStaleReadings(stale.join(', ')),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 6),
            InlineStatusNotice(
              icon: Icons.info_outline,
              message: context.lang.mealDecisionContextMissingReadings(
                missing.join(', '),
              ),
            ),
          ],
          for (final notice in notices) ...[const SizedBox(height: 6), notice],
        ],
      ),
    );
  }
}
