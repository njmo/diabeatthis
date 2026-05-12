import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
                  title: 'Aktywność',
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
                          return 'Podaj nazwę aktywności';
                        }
                        return null;
                      },
                      onSaved: (value) {
                        activityDraft.setName(value?.trim() ?? '');
                      },
                      decoration: const InputDecoration(
                        prefixIcon: Icon(Icons.badge_outlined),
                        labelText: 'Nazwa aktywności',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: hasPlannedDuration,
                      onChanged: (value) {
                        activityDraft.setHasPlannedDuration(value ?? false);
                      },
                      title: const Text('Ma planowany czas trwania'),
                      subtitle: const Text(
                        'Odznacz, jeśli aktywność kończysz ręcznie',
                      ),
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
                            return 'Podaj czas w minutach';
                          }
                          return null;
                        },
                        onSaved: (value) {
                          activityDraft.setDurationMinutes(value?.trim() ?? '');
                        },
                        decoration: const InputDecoration(
                          prefixIcon: Icon(Icons.timer_outlined),
                          suffixText: 'min',
                          labelText: 'Czas trwania',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),
                FormSection(
                  title: 'Wrażliwość na insulinę',
                  icon: Icons.percent,
                  subtitle:
                      'O ile obniżyć dawkę insuliny w kontekście aktywności.',
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
                            validator: _percentageValidator,
                            onSaved: (value) {
                              activityDraft.setPercentagePre(
                                value?.trim() ?? '',
                              );
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.schedule),
                              suffixText: '%',
                              labelText: '1h przed',
                              border: OutlineInputBorder(),
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
                            validator: _percentageValidator,
                            onSaved: (value) {
                              activityDraft.setPercentagePost(
                                value?.trim() ?? '',
                              );
                            },
                            decoration: const InputDecoration(
                              prefixIcon: Icon(Icons.sports_score),
                              suffixText: '%',
                              labelText: 'Po treningu',
                              border: OutlineInputBorder(),
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

  String? _percentageValidator(String? value) {
    final percentage = int.tryParse(value?.trim() ?? '');
    if (percentage == null || percentage <= 0 || percentage >= 100) {
      return 'Podaj obniżenie od 1 do 99%';
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
