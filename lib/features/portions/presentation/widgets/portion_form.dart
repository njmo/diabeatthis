import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/forms.dart';
import '../../../../common/widgets/status_info_card.dart';
import '../../../meals/data/providers/add_ingredients_provider.dart';
import '../../data/providers/portion_provider.dart';

class PortionForm extends HookConsumerWidget {
  final GlobalKey<FormState>? formKey;

  const PortionForm({this.formKey, super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = context.lang;
    final draft = ref.watch(portionDraftProvider.notifier);
    final effectiveFormKey =
        formKey ?? ref.watch(mealIngredientFormKeyProvider);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: effectiveFormKey,
        autovalidateMode: AutovalidateMode.disabled,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            StatusInfoCard(
              icon: Icons.add,
              title: lang.portionNewTitle,
              subtitle: lang.portionNewSubtitle,
            ),
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
                        (value.trim().isEmpty) ||
                        (value.trim().length < 3)) {
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
                    if ((value == null) || (value.trim().isEmpty)) {
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
