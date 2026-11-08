import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/domain/model/extended_carb.dart';
import '../../../core/domain/model/treat.dart';
import '../../../core/domain/model/treatment_base.dart';
import '../../l10n/language.dart';
import '../../widgets/inline_status_notice.dart';

/// Only valid recorded carbohydrate entries overlapping the requested window.
/// Ordinary carbs are point events; extended carbs are intervals in milliseconds.
class MealDecisionCarbohydrateNotices extends StatelessWidget {
  const MealDecisionCarbohydrateNotices({
    super.key,
    required this.treatments,
    required this.now,
    required this.until,
  });

  final List<Treatment> treatments;
  final DateTime now, until;

  @override
  Widget build(BuildContext context) {
    String time(DateTime at) =>
        DateFormat.Hm(context.lang.localeName).format(at.toLocal());
    final messages = <String>[];
    if (until.isAfter(now)) {
      for (final treatment in treatments) {
        if (!treatment.isValid) continue;
        if (treatment case Treat(:final carbs, :final createdAt)) {
          if (carbs > 0 &&
              createdAt.isAfter(now) &&
              !createdAt.isAfter(until)) {
            messages.add(
              context.lang.mealDecisionContextPlannedCarbs(
                carbs,
                time(createdAt),
              ),
            );
          }
        } else if (treatment case ExtendedCarb(
          :final carbs,
          :final duration,
          :final createdAt,
        )) {
          final end = createdAt.add(Duration(milliseconds: duration));
          if (carbs > 0 &&
              duration > 0 &&
              end.isAfter(now) &&
              !createdAt.isAfter(until)) {
            messages.add(
              createdAt.isAfter(now)
                  ? context.lang.mealDecisionContextPlannedExtendedCarbs(
                      carbs,
                      time(createdAt),
                      time(end),
                    )
                  : context.lang.mealDecisionContextExtendedCarbs(
                      carbs,
                      time(createdAt),
                      time(end),
                    ),
            );
          }
        }
      }
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < messages.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          InlineStatusNotice(
            icon: Icons.warning_amber_rounded,
            iconColor: Colors.amber.shade700,
            message: messages[i],
          ),
        ],
      ],
    );
  }
}
