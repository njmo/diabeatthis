import 'package:flutter/material.dart';

class ReviewSectionHeader extends StatelessWidget {
  const ReviewSectionHeader({
    super.key,
    required this.title,
    required this.actionLabel,
    required this.onChange,
  });
  final String title;
  final String actionLabel;
  final VoidCallback onChange;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(title, style: Theme.of(context).textTheme.titleMedium),
      ),
      TextButton(onPressed: onChange, child: Text(actionLabel)),
    ],
  );
}
