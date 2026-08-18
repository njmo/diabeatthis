import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/form_section.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/activity_provider.dart';

class ActivityForm extends HookConsumerWidget {
  const ActivityForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = ref.watch(mealIngredientFormKeyProvider);
    ref.watch(activityDraftProvider);
    final activityDraft = ref.watch(activityDraftProvider.notifier);
    final hasPlannedDuration = activityDraft.hasPlannedDuration();
    final availableHeight =
        MediaQuery.sizeOf(context).height -
        MediaQuery.viewInsetsOf(context).bottom -
        220;
    final maxHeight = availableHeight.clamp(240.0, 520.0);

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: Form(
            key: formKey,
            autovalidateMode: AutovalidateMode.always,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FormSection(
                  title: context.lang.activityTitle,
                  icon: Icons.directions_run,
                  children: [
                    TextFormField(
                      key: const ValueKey('activity-name-field'),
                      initialValue: activityDraft.getName(),
                      maxLength: 30,
                      textInputAction: TextInputAction.next,
                      validator: (value) {
                        final text = value?.trim() ?? '';
                        if (text.length < 2) {
                          return context.lang.activityNameRequired;
                        }
                        return null;
                      },
                      onSaved: (value) {
                        activityDraft.setName(value?.trim() ?? '');
                      },
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.badge_outlined),
                        labelText: context.lang.activityNameLabel,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: hasPlannedDuration,
                      onChanged: (value) {
                        activityDraft.setHasPlannedDuration(value ?? false);
                      },
                      title: Text(context.lang.activityHasPlannedDurationTitle),
                      subtitle: Text(context.lang.activityManualEndHint),
                    ),
                    if (hasPlannedDuration) ...[
                      const SizedBox(height: 8),
                      TextFormField(
                        key: const ValueKey('activity-duration-field'),
                        initialValue:
                            activityDraft.getDurationMinutes()?.toString() ??
                            '',
                        keyboardType: TextInputType.number,
                        textInputAction: TextInputAction.next,
                        maxLength: 4,
                        validator: (value) {
                          final duration = int.tryParse(value?.trim() ?? '');
                          if (duration == null || duration <= 0) {
                            return context.lang.activityDurationRequired;
                          }
                          return null;
                        },
                        onSaved: (value) {
                          activityDraft.setDurationMinutes(value?.trim() ?? '');
                        },
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.timer_outlined),
                          suffixText: 'min',
                          labelText: context.lang.activityDurationLabel,
                          border: const OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                FormSection(
                  title: context.lang.activityInsulinSensitivityTitle,
                  icon: Icons.percent,
                  subtitle: context.lang.activityInsulinSensitivitySubtitle,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey(
                              'activity-percentage-pre-field',
                            ),
                            initialValue: _initialPercentageValue(
                              activityDraft.getPercentagePre(),
                            ),
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            maxLength: 3,
                            validator: (value) =>
                                _percentageValidator(context, value),
                            onSaved: (value) {
                              activityDraft.setPercentagePre(
                                value?.trim() ?? '',
                              );
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.schedule),
                              suffixText: '%',
                              labelText:
                                  context.lang.activityOneHourBeforeShortLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextFormField(
                            key: const ValueKey(
                              'activity-percentage-post-field',
                            ),
                            initialValue: _initialPercentageValue(
                              activityDraft.getPercentagePost(),
                            ),
                            keyboardType: TextInputType.number,
                            maxLength: 3,
                            validator: (value) =>
                                _percentageValidator(context, value),
                            onSaved: (value) {
                              activityDraft.setPercentagePost(
                                value?.trim() ?? '',
                              );
                            },
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.sports_score),
                              suffixText: '%',
                              labelText: context.lang.activityAfterWorkoutLabel,
                              border: const OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String? _percentageValidator(BuildContext context, String? value) {
    final percentage = int.tryParse(value?.trim() ?? '');
    if (percentage == null || percentage <= 0 || percentage >= 100) {
      return context.lang.activityPercentageRequired;
    }
    return null;
  }

  String _initialPercentageValue(int? value) {
    if (value == null || value == 0) {
      return '';
    }
    return value.toString();
  }
}
