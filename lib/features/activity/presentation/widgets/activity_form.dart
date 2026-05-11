import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
      width: MediaQuery.of(context).size.width * 0.8,
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
                TextFormField(
                  key: const ValueKey('activity-name-field'),
                  initialValue: activityDraft.getName(),
                  maxLength: 30,
                  validator: (value) {
                    final text = value?.trim() ?? '';
                    if (text.length < 2) {
                      return '';
                    }
                    return null;
                  },
                  onSaved: (value) {
                    activityDraft.setName(value?.trim() ?? '');
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nazwa aktywnosci',
                    border: OutlineInputBorder(),
                  ),
                ),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: hasPlannedDuration,
                  onChanged: (value) {
                    activityDraft.setHasPlannedDuration(value ?? false);
                  },
                  title: const Text('Aktywność ma start i koniec'),
                  subtitle: const Text('Odznacz, jeśli kończysz ją ręcznie'),
                ),
                if (hasPlannedDuration)
                  TextFormField(
                    key: const ValueKey('activity-duration-field'),
                    initialValue:
                        activityDraft.getDurationMinutes()?.toString() ?? '',
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (value) {
                      final duration = int.tryParse(value?.trim() ?? '');
                      if (duration == null || duration <= 0) {
                        return '';
                      }
                      return null;
                    },
                    onSaved: (value) {
                      activityDraft.setDurationMinutes(value?.trim() ?? '');
                    },
                    decoration: const InputDecoration(
                      labelText: 'Czas trwania w minutach',
                      border: OutlineInputBorder(),
                    ),
                  ),
                TextFormField(
                  key: const ValueKey('activity-percentage-pre-field'),
                  initialValue: _initialPercentageValue(
                    activityDraft.getPercentagePre(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  validator: _percentageValidator,
                  onSaved: (value) {
                    activityDraft.setPercentagePre(value?.trim() ?? '');
                  },
                  decoration: const InputDecoration(
                    labelText: 'Procent przed wysilkiem',
                    border: OutlineInputBorder(),
                  ),
                ),
                TextFormField(
                  key: const ValueKey('activity-percentage-post-field'),
                  initialValue: _initialPercentageValue(
                    activityDraft.getPercentagePost(),
                  ),
                  keyboardType: TextInputType.number,
                  maxLength: 3,
                  validator: _percentageValidator,
                  onSaved: (value) {
                    activityDraft.setPercentagePost(value?.trim() ?? '');
                  },
                  decoration: const InputDecoration(
                    labelText: 'Procent po wysilku',
                    border: OutlineInputBorder(),
                  ),
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
      return '';
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
