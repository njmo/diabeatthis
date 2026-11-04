import 'package:flutter/material.dart';

/// Keeps portion mass as the primary action in a food review card.
class PortionAmountField extends StatelessWidget {
  const PortionAmountField({
    super.key,
    required this.controller,
    required this.label,
    required this.onChanged,
  });
  final TextEditingController controller;
  final String label;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Flexible(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Semantics(
              label: label,
              child: TextField(
                controller: controller,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.displaySmall,
                decoration: const InputDecoration(
                  isDense: true,
                  border: UnderlineInputBorder(),
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 8,
                  ),
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                onChanged: onChanged,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('g', style: Theme.of(context).textTheme.titleMedium),
      ],
    ),
  );
}
