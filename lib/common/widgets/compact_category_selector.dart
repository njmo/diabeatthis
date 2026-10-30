import 'package:flutter/material.dart';

class CompactCategorySelector extends StatelessWidget {
  const CompactCategorySelector({
    super.key,
    required this.labels,
    required this.icons,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<String> labels;
  final List<IconData> icons;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var index = 0; index < labels.length; index++) ...[
        if (index > 0) const SizedBox(width: 6),
        Tooltip(
          message: labels[index],
          child: Semantics(
            selected: selectedIndex == index,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(44, 44),
                padding: const EdgeInsets.symmetric(horizontal: 10),
                backgroundColor: selectedIndex == index
                    ? Theme.of(context).colorScheme.primaryContainer
                    : null,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => onSelected(index),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icons[index], size: 20),
                  if (selectedIndex == index &&
                      MediaQuery.sizeOf(context).width >= 360 &&
                      MediaQuery.textScalerOf(context).scale(14) <= 19) ...[
                    const SizedBox(width: 6),
                    Text(labels[index]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
