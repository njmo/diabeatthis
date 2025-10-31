import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

import '../../../../common/widgets/forms.dart';
import '../../data/providers/portion_provider.dart';

class PortionForm extends HookConsumerWidget {
  PortionForm({super.key});

  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final draft = ref.watch(portionDraftProvider.notifier);

    return AlertDialog(
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.always,
          child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StringFormField(
                    label: 'Nazwa',
                    value: '',
                    onChanged: draft.setName,
                    builder: (context, controller) {
                      return TextFormField(
                        controller: controller,
                        maxLength: 30,
                        validator: (value) {
                          if ((value == null)) {
                            return 'Nazwa nie moze byc pusta';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Nazwa',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  StringFormField(
                    label: 'Jednostka',
                    value: '',
                    onChanged: draft.setUnitHint,
                    builder: (context, controller) {
                      return TextFormField(
                        controller: controller,
                        maxLength: 30,
                        validator: (value) {
                          if ((value == null)) {
                            return 'Jednostka nie moze byc pusta';
                          }
                          return null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Jednostka',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
      actions: [
        Row(
          children: [
            Expanded(
              child: TextButton(
                onPressed: () {
                  final currentState = _formKey.currentState;
                  if (currentState != null && currentState.validate()) {
                    final portion = ref.read(portionDraftProvider);
                    Navigator.of(context).pop(portion);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Blad w weryfikacji formularza')),
                    );
                  }
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
