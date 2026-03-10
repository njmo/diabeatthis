import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

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
              Text("Zdefiniu ilosc porcji"),
              SizedBox(height: 16),
              StringFormField(
                label: 'Ilosc porcji',
                value: '',
                onChanged: (value) { amount.value = value; },
                builder: (context, controller) {
                  return TextFormField(
                    controller: controller,
                    maxLength: 30,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    validator: (value) {
                      if ((value == null)) {
                        return 'Ilosc porcji';
                      }
                      return null;
                    },
                    decoration: const InputDecoration(
                      labelText: 'Ilosc porcji',
                      border: OutlineInputBorder(),
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
                child: const Text('Add'),
              ),
            ),
            Expanded(
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
