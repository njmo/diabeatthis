import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/meal/meal_display_name.dart';
import '../../../../common/widgets/meal_completion/meal_eating_finish_time_step.dart';
import '../../../../core/domain/model/meal_status_flow.dart';
import '../providers/meal_completion_context_provider.dart';
import '../screens/meal_completion_view.dart';

class MealCompletionEntry extends ConsumerStatefulWidget {
  const MealCompletionEntry({
    super.key,
    required this.mealId,
    this.confirmedEatingEndedAt,
    this.chooseEarlier = false,
    this.compactChoice = false,
  });

  final int mealId;
  final DateTime? confirmedEatingEndedAt;
  final bool chooseEarlier;
  final bool compactChoice;

  @override
  ConsumerState<MealCompletionEntry> createState() =>
      MealCompletionEntryState();
}

class MealCompletionEntryState extends ConsumerState<MealCompletionEntry> {
  DateTime? confirmedEnd;
  bool requestedEarlier = false;

  @override
  Widget build(BuildContext context) => ref
      .watch(mealCompletionContextProvider(widget.mealId))
      .when(
        loading: () => widget.compactChoice
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: SizedBox(
                  height: 40,
                  child: Center(child: CircularProgressIndicator()),
                ),
              )
            : Scaffold(
                appBar: AppBar(title: Text(context.lang.mealEatingFinishTitle)),
                body: const Center(child: CircularProgressIndicator()),
              ),
        error: (error, _) => widget.compactChoice
            ? Padding(
                padding: const EdgeInsets.all(20),
                child: Text(context.lang.mealSummaryLoadError(error)),
              )
            : Scaffold(
                appBar: AppBar(title: Text(context.lang.mealEatingFinishTitle)),
                body: Center(
                  child: Text(context.lang.mealSummaryLoadError(error)),
                ),
              ),
        data: (details) {
          final status = details.meal.status;
          final ready = mealStatusReadyToSummarize(status);
          if (!ready &&
              !mealStatusesStartingEating.contains(status) &&
              status != 'eating-extra') {
            if (widget.compactChoice) {
              return Padding(
                padding: const EdgeInsets.all(20),
                child: Text(context.lang.mealCompletionStale),
              );
            }
            return Scaffold(
              appBar: AppBar(title: Text(context.lang.mealEatingFinishTitle)),
              body: Center(child: Text(context.lang.mealCompletionStale)),
            );
          }
          final now = clock.now();
          final chooseEarlier = requestedEarlier || widget.chooseEarlier;
          final chosen =
              confirmedEnd ??
              (requestedEarlier ? null : widget.confirmedEatingEndedAt);
          final recorded = details.timing.endedAt;
          var accepted = details.timing.isValidEnd(chosen, now)
              ? chosen
              : ready &&
                    !chooseEarlier &&
                    details.timing.isValidEnd(recorded, now) &&
                    !details.timing.needsTimeConfirmation(now)
              ? recorded
              : null;
          if (accepted == null &&
              !ready &&
              !chooseEarlier &&
              details.timing.canAssumeEndedNow(now)) {
            // Freeze the time of the user's finish action; editing quantities
            // or returning to the app later must not move it forward.
            accepted = confirmedEnd = now;
          }
          if (accepted != null) {
            return MealCompletionView(
              mealId: widget.mealId,
              confirmedEatingEndedAt: accepted,
              compactChoice: widget.compactChoice,
              onEarlierRequested: widget.compactChoice
                  ? () => setState(() {
                      requestedEarlier = true;
                      confirmedEnd = null;
                    })
                  : null,
            );
          }
          final timeStep = MealEatingFinishTimeStep(
            timing: details.timing,
            chooseEarlier: chooseEarlier,
            mealName: mealDisplayName(details.meal.name),
            onConfirmed: (value) => setState(() => confirmedEnd = value),
          );
          return widget.compactChoice
              ? SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.8,
                  child: timeStep,
                )
              : timeStep;
        },
      );
}
