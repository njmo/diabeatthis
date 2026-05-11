import 'package:flutter/material.dart';

import 'meal_status_dialog_result.dart';

class MealAddOnModeDialog extends StatelessWidget {
  const MealAddOnModeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Dokładka'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.looks_one_outlined),
            title: const Text('1,5 porcji'),
            onTap: () =>
                Navigator.of(context).pop(MealAddOnChoice.oneAndHalfPortion),
          ),
          ListTile(
            leading: const Icon(Icons.looks_two_outlined),
            title: const Text('2 porcje'),
            onTap: () =>
                Navigator.of(context).pop(MealAddOnChoice.doublePortion),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.tune),
            title: const Text('Tryb zaawansowany'),
            subtitle: const Text('Zmień ilości albo dodaj składniki'),
            onTap: () => Navigator.of(context).pop(MealAddOnChoice.advanced),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Anuluj'),
        ),
      ],
    );
  }
}
