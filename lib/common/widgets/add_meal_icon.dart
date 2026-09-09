import 'package:flutter/material.dart';

class AddMealIcon extends StatelessWidget {
  const AddMealIcon({super.key});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: 24,
    child: Stack(
      children: [
        const Align(
          alignment: Alignment.topLeft,
          child: Icon(Icons.restaurant, size: 21),
        ),
        Positioned(
          right: 0,
          bottom: 0,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.add_circle, size: 13),
          ),
        ),
      ],
    ),
  );
}
