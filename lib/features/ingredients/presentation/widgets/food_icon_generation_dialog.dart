import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../common/l10n/language.dart';
import '../../../../core/logger/logger.dart';
import '../../data/icons/food_icon_generation_provider.dart';
import '../../data/icons/food_icon_generation_result.dart';
import 'ingredient_icon_error_message.dart';

class FoodIconGenerationDialog extends ConsumerStatefulWidget {
  const FoodIconGenerationDialog({super.key, required this.name});

  final String name;

  @override
  ConsumerState<FoodIconGenerationDialog> createState() =>
      FoodIconGenerationDialogState();
}

class FoodIconGenerationDialogState
    extends ConsumerState<FoodIconGenerationDialog> {
  FoodIconGenerationResult? result;
  Object? error;
  String? acceptedPath;
  bool withoutBackground = true;

  @override
  void initState() {
    super.initState();
    unawaited(run());
  }

  Future<void> run() async {
    try {
      final generated = await ref
          .read(foodIconGenerationServiceProvider)
          .run(widget.name);
      if (!mounted) {
        await generated.discardUnused();
        return;
      }
      setState(() => result = generated);
    } catch (failure) {
      Log.w('FoodIconGeneration', 'Generation failed: $failure');
      if (mounted) setState(() => error = failure);
    }
  }

  @override
  void dispose() {
    final generated = result;
    if (generated != null) {
      unawaited(generated.discardUnused(keepPath: acceptedPath));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final generated = result;
    return AlertDialog(
      title: Text(context.lang.ingredientGenerateIcon),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (generated != null) ...[
              Image.file(
                !withoutBackground && generated.originalFile != null
                    ? generated.originalFile!
                    : generated.file,
                width: 192,
                height: 192,
              ),
              if (generated.backgroundRemoved)
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(context.lang.ingredientIconWithoutBackground),
                  value: withoutBackground,
                  onChanged: (value) =>
                      setState(() => withoutBackground = value),
                )
              else
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(context.lang.ingredientIconBackgroundKept),
                ),
            ] else if (error != null)
              Text(ingredientIconErrorMessage(context.lang, error))
            else ...[
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(context.lang.ingredientGeneratingIcon),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.lang.commonCancel),
        ),
        if (generated != null)
          FilledButton(
            onPressed: () {
              acceptedPath =
                  !withoutBackground && generated.originalPath != null
                  ? generated.originalPath!
                  : generated.path;
              Navigator.of(context).pop(acceptedPath);
            },
            child: Text(context.lang.ingredientUseGeneratedIcon),
          ),
      ],
    );
  }
}
