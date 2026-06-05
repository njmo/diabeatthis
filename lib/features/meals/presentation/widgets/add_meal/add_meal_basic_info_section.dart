import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../../common/widgets/date_time_picker.dart';
import '../../../../../common/widgets/form_section.dart';
import '../../../data/providers/meal_draft_provider.dart';

class AddMealBasicInfoSection extends ConsumerWidget {
  const AddMealBasicInfoSection({
    super.key,
    required this.onNameSaved,
    required this.onPlannedAtSaved,
  });

  final ValueChanged<String> onNameSaved;
  final ValueChanged<DateTime> onPlannedAtSaved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mealName = ref.watch(mealDraftProvider.select((draft) => draft.name));

    return FormSection(
      icon: Icons.restaurant_menu,
      title: 'Podstawowe informacje',
      subtitle: 'Nazwij posiłek i wybierz, kiedy jest planowany.',
      children: [
        TextFormField(
          key: ValueKey(mealName),
          initialValue: mealName,
          maxLength: 120,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final name = value?.trim() ?? '';
            if (name.length < 5) {
              return 'Wpisz nazwę posiłku';
            }
            return null;
          },
          onSaved: (value) => onNameSaved(value!.trim()),
          decoration: const InputDecoration(
            labelText: 'Nazwa',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FormField<DateTime>(
          validator: (value) => value == null ? 'Wybierz datę' : null,
          onSaved: (value) {
            if (value != null) {
              onPlannedAtSaved(value);
            }
          },
          builder: (state) {
            final selectedDate = state.value;

            return InkWell(
              borderRadius: BorderRadius.circular(4),
              onTap: () async {
                final selectedDateTime = await showDateTimePicker(
                  context: context,
                  initialDate: selectedDate ?? clock.now(),
                  firstDate: clock.now().subtract(const Duration(days: 1)),
                  lastDate: clock.now().add(const Duration(days: 5)),
                );
                if (selectedDateTime != null) {
                  state.didChange(selectedDateTime);
                }
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  icon: const Icon(Icons.calendar_today_rounded),
                  labelText: 'Planowana data',
                  border: const OutlineInputBorder(),
                  errorText: state.errorText,
                ),
                child: Text(
                  selectedDate == null
                      ? 'Wybierz datę i godzinę'
                      : _formatPlannedAt(selectedDate),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

String _formatPlannedAt(DateTime value) {
  final day = value.day.toString().padLeft(2, '0');
  final month = value.month.toString().padLeft(2, '0');
  final year = value.year.toString();
  final hour = value.hour.toString().padLeft(2, '0');
  final minute = value.minute.toString().padLeft(2, '0');
  return '$day.$month.$year $hour:$minute';
}
