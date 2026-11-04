import 'package:flutter/material.dart';

import '../../l10n/language.dart';
import '../ingredient_identity.dart';
import '../ingredient_origin_repository.dart';

class IngredientOriginBadge extends StatelessWidget {
  const IngredientOriginBadge({super.key, required this.origin});

  final IngredientOriginSnapshot origin;

  @override
  Widget build(BuildContext context) {
    final fromCloud = origin.identity.source == IngredientSource.firebase;
    final isCloudCopy = origin.creationMethod == 'catalog_copy';
    final label = fromCloud
        ? context.lang.ingredientOriginCloud
        : isCloudCopy
        ? context.lang.ingredientOriginCloudCopy
        : context.lang.ingredientOriginLocal;
    return Row(
      children: [
        Icon(
          fromCloud || isCloudCopy
              ? Icons.cloud_download_outlined
              : Icons.phone_android_outlined,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
      ],
    );
  }
}
