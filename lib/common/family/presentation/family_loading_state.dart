import 'package:flutter/material.dart';

import '../../l10n/language.dart';

class FamilyLoadingState extends StatelessWidget {
  const FamilyLoadingState({super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 12),
        Flexible(child: Text(context.lang.familyLoading)),
      ],
    ),
  );
}
