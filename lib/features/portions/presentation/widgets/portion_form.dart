import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/forms.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/portion_provider.dart';

class PortionForm extends HookConsumerWidget {
  const PortionForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final draft = ref.watch(portionDraftProvider.notifier);
    final formKey = ref.watch(mealIngredientFormKeyProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: formKey,
        autovalidateMode: AutovalidateMode.always,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PortionFormHeader(),
            const SizedBox(height: 16),
            StringFormField(
              label: lang.portionNameLabel,
              value: draft.getName(),
              onChanged: draft.setName,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) ||
                        (value.isEmpty) ||
                        (value.length < 3)) {
                      return '';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.local_dining_outlined),
                    labelText: lang.portionNameLabel,
                    helperText: lang.portionNameHelper,
                    counterText: '',
                    border: const OutlineInputBorder(),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            StringFormField(
              label: lang.portionUnitLabel,
              value: draft.getUnitHint(),
              onChanged: draft.setUnitHint,
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  validator: (value) {
                    if ((value == null) || (value.isEmpty)) {
                      return '';
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.scale_outlined),
                    labelText: lang.portionWeightUnitLabel,
                    helperText: lang.portionWeightUnitHelper,
                    counterText: '',
                    border: const OutlineInputBorder(),
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

class PortionFormHeader extends StatelessWidget {
  const PortionFormHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final lang = context.lang;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: const Icon(Icons.add),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(lang.portionNewTitle, style: textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    lang.portionNewSubtitle,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
