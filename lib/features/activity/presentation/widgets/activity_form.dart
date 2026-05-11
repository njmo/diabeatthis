import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
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

    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.8,
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StringFormField(
              label: 'Nazwa aktywnosci',
              value: activityDraft.getName(),
              onChanged: activityDraft.setName,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) ||
                        (value.isEmpty) ||
                        (value.length < 4)) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Nazwa aktywnosci',
                    border: OutlineInputBorder(),
                  ),
                );
              },
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
              StringFormField(
                label: 'Czas trwania w minutach',
                value: activityDraft.getDurationMinutes()?.toString() ?? '',
                onChanged: activityDraft.setDurationMinutes,
                builder: (context, controller) {
                  return TextFormField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    validator: (value) {
                      final duration = int.tryParse(value?.trim() ?? '');
                      if (duration == null || duration <= 0) {
                        return '';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Czas trwania w minutach',
                      border: OutlineInputBorder(),
                    ),
                  );
                },
              ),
            StringFormField(
              label: 'Procent 1.5h po wysilku',
              value: activityDraft.getPercentagePost().toString(),
              onChanged: activityDraft.setPercentagePost,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) ||
                        (value.isEmpty) ||
                        (value.length < 4)) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Procent przed wysilkiem',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
            StringFormField(
              label: 'Procent 1.5h przed wysilkiem',
              value: activityDraft.getPercentagePre().toString(),
              onChanged: activityDraft.setPercentagePre,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) ||
                        (value.isEmpty) ||
                        (value.length < 4)) {
                      return '';
                    }
                    return null;
                  },
                  decoration: const InputDecoration(
                    labelText: 'Procent po wysilku',
                    border: OutlineInputBorder(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
