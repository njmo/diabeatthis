import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/forms.dart';

class PortionAmountForm extends HookConsumerWidget {
  const PortionAmountForm({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final amount = useState('');
    return AlertDialog(
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.lang.portionAmountTitle),
            const SizedBox(height: 16),
            StringFormField(
              label: context.lang.portionAmountLabel,
              value: '',
              onChanged: (value) {
                amount.value = value;
              },
              builder: (context, controller) {
                return TextFormField(
                  controller: controller,
                  maxLength: 30,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return context.lang.portionAmountRequired;
                    }
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: context.lang.portionAmountLabel,
                    border: const OutlineInputBorder(),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  Navigator.of(context).pop(int.tryParse(amount.value) ?? 0);
                },
                child: Text(context.lang.mealSummaryExtraAdd),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(context.lang.settingsCancel),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
