import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/treat.dart';
import '../../../low_treatment/domain/models/low_treatment_review_list.dart';
import '../../../low_treatment/domain/models/recorded_low_treatment.dart';
import '../../../low_treatment/presentation/widgets/delete_recorded_low_treatment_button.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_relation_editor.dart';
import '../../../low_treatment/presentation/widgets/low_treatment_sheet.dart';
import '../../data/providers/day_context_provider.dart';
import '../../data/providers/day_low_treatment_review_provider.dart';
import '../controllers/day_low_treatment_review_controller.dart';
import 'day_linked_low_treatment_review_card.dart';
import 'day_low_treatment_picker.dart';
import 'day_low_treatment_review_tile.dart';

class DayLowTreatmentReviewSection extends ConsumerWidget {
  final DateTime date;
  const DayLowTreatmentReviewSection({super.key, required this.date});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entries = ref.watch(dayLowTreatmentReviewProvider(date));
    final busy = ref
        .watch(dayLowTreatmentReviewControllerProvider(date))
        .isLoading;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        Text(
          context.lang.dayReviewLowTitle,
          style: Theme.of(context).textTheme.titleLarge,
        ),
        entries.when(
          loading: () => const LinearProgressIndicator(),
          error: (_, _) => TextButton.icon(
            onPressed: () {
              ref.invalidate(dayContextProvider);
              ref.invalidate(dayContextForDateProvider(date));
              ref.invalidate(dayLowTreatmentReviewProvider(date));
            },
            icon: const Icon(Icons.warning_amber),
            label: Text(context.lang.dayReviewLoadFailed),
          ),
          data: (items) {
            final review = LowTreatmentReviewList(items);
            final lows = review.recorded;
            final linked = review.linkedEvents;
            final pending = review.pendingCount;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (pending > 0)
                  Text(context.lang.dayReviewPendingCount(pending)),
                if (items.isEmpty) Text(context.lang.dayReviewEmpty),
                ...review.visible.map(
                  (entry) => (linked[entry.recorded?.mealId]?.length ?? 0) > 1
                      ? DayLinkedLowTreatmentReviewCard(
                          recorded: entry.recorded!,
                          relationEditor: _relationEditor(
                            ref,
                            entry.recorded!,
                            busy,
                          ),
                          events: linked[entry.recorded!.mealId]!,
                          busy: busy,
                          onReset: (event) => _save(
                            context,
                            () => ref
                                .read(
                                  dayLowTreatmentReviewControllerProvider(
                                    date,
                                  ).notifier,
                                )
                                .reset(event.createdAt),
                          ),
                        )
                      : DayLowTreatmentReviewTile(
                          entry: entry,
                          relationEditor: entry.recorded == null
                              ? null
                              : _relationEditor(ref, entry.recorded!, busy),
                          busy: busy,
                          onLink: () => _link(context, ref, entry.event!, lows),
                          onCreate: () => _create(context, ref, entry.event!),
                          onDismiss: () => _save(
                            context,
                            () => ref
                                .read(
                                  dayLowTreatmentReviewControllerProvider(
                                    date,
                                  ).notifier,
                                )
                                .resolve(entry.event!, dismissed: true),
                          ),
                          onReset: () => _save(
                            context,
                            () => ref
                                .read(
                                  dayLowTreatmentReviewControllerProvider(
                                    date,
                                  ).notifier,
                                )
                                .reset(entry.occurredAt),
                          ),
                        ),
                ),
                if (review.dismissed.isNotEmpty)
                  ExpansionTile(
                    title: Text(context.lang.dayReviewDismissed),
                    children: [
                      ...review.dismissed.map(
                        (entry) => ListTile(
                          title: Text(
                            '${DateFormat('HH:mm').format(entry.occurredAt)} · ${entry.event!.carbs} g',
                          ),
                          trailing: IconButton(
                            tooltip: context.lang.dayReviewUndo,
                            onPressed: busy
                                ? null
                                : () => _save(
                                    context,
                                    () => ref
                                        .read(
                                          dayLowTreatmentReviewControllerProvider(
                                            date,
                                          ).notifier,
                                        )
                                        .reset(entry.occurredAt),
                                  ),
                            icon: const Icon(Icons.undo),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Widget _relationEditor(WidgetRef ref, RecordedLowTreatment low, bool busy) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LowTreatmentRelationEditor(
            mealId: low.mealId,
            occurredAt: low.eatenAt,
            relatedMealId: low.relatedMealId,
            relatedActivityLogId: low.relatedActivityLogId,
            busy: busy,
            onChanged: (relation) => ref
                .read(dayLowTreatmentReviewControllerProvider(date).notifier)
                .updateRelation(low.mealId, relation),
          ),
          DeleteRecordedLowTreatmentButton(
            busy: busy,
            onDelete: () => _save(
              ref.context,
              () => ref
                  .read(dayLowTreatmentReviewControllerProvider(date).notifier)
                  .deleteRecorded(low.mealId),
            ),
          ),
        ],
      );

  Future<void> _link(
    BuildContext context,
    WidgetRef ref,
    Treat event,
    List<RecordedLowTreatment> lows,
  ) async {
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DayLowTreatmentPicker(entries: lows),
    );
    if (id == null || !context.mounted) return;
    await _save(
      context,
      () => ref
          .read(dayLowTreatmentReviewControllerProvider(date).notifier)
          .resolve(event, mealId: id),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref, Treat event) async {
    final saved = await showLowTreatmentSheet(
      context,
      historicalAt: event.createdAt,
    );
    if (saved == null || !context.mounted) return;
    await _save(
      context,
      () => ref
          .read(dayLowTreatmentReviewControllerProvider(date).notifier)
          .resolve(event, mealId: saved.mealId, created: true),
      message: context.lang.dayReviewLowSavedUnlinked,
    );
  }

  Future<void> _save(
    BuildContext context,
    Future<void> Function() action, {
    String? message,
  }) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message ?? context.lang.dayReviewSaveFailed)),
        );
      }
    }
  }
}
