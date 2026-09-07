import 'package:flutter/material.dart';

class BottomSheetStepHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final int? titleMaxLines;

  const BottomSheetStepHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
    this.titleMaxLines,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
        Expanded(
          child: Text(
            title,
            maxLines: titleMaxLines,
            overflow: titleMaxLines == null ? null : TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        ...actions,
      ],
    );
  }
}
