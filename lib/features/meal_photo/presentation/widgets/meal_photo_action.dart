import 'package:auto_route/auto_route.dart';
import 'package:flutter/material.dart';

import '../../../../app/router/app_router.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/widgets/fab_action_option.dart';

class MealPhotoAction extends StatelessWidget {
  const MealPhotoAction({
    super.key,
    required this.onOpening,
    this.tile = false,
    this.horizontal = false,
  });
  final VoidCallback onOpening;
  final bool tile;
  final bool horizontal;
  @override
  Widget build(BuildContext context) => FabActionOption(
    tile: tile,
    horizontal: horizontal,
    icon: Icons.add_a_photo_outlined,
    label: context.lang.mealPhotoTitle,
    onTap: () {
      onOpening();
      context.router.push(MealPhotoRoute());
    },
  );
}
