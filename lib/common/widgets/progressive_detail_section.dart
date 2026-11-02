import 'package:flutter/material.dart';

/// Builds optional detail only when requested, keeping the overview focused.
class ProgressiveDetailSection extends StatefulWidget {
  final String title;
  final WidgetBuilder builder;

  const ProgressiveDetailSection({
    super.key,
    required this.title,
    required this.builder,
  });

  @override
  State<ProgressiveDetailSection> createState() =>
      ProgressiveDetailSectionState();
}

class ProgressiveDetailSectionState extends State<ProgressiveDetailSection> {
  bool expanded = false;

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      title: Text(widget.title),
      onExpansionChanged: (value) => setState(() => expanded = value),
      childrenPadding: const EdgeInsets.all(12),
      children: [if (expanded) widget.builder(context)],
    ),
  );
}
