import 'package:flutter/material.dart';

class BottomSheetStepHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;

  const BottomSheetStepHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        ...actions,
      ],
    );
  }
}
