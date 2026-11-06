import 'package:flutter/material.dart';

class SetupIconBubble extends StatelessWidget {
  const SetupIconBubble({super.key, required this.icon});
  final IconData icon;
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 21,
    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
    child: Icon(icon, color: Theme.of(context).colorScheme.onPrimaryContainer),
  );
}
