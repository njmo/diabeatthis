import 'package:auto_route/auto_route.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../../common/family_chat/application/family_chat_runtime.dart';
import '../../../../common/family_chat/application/family_chat_settings_runtime.dart';
import '../../../../common/family_chat/data/family_chat_preferences_provider.dart';
import '../../../../common/family_chat/presentation/family_chat_conversation.dart';
import '../../../../common/family_chat/presentation/family_chat_page.dart';
import '../../../../common/ingredient_catalog/ingredient_catalog_providers.dart';
import '../../../../common/ingredient_catalog/widgets/ingredient_catalog_picker.dart';
import '../../../../common/l10n/language.dart';
import '../../../../core/domain/model/net_carbs_calculator.dart';
import '../../../../core/drift/mappers/ingredient_drift_mapper.dart';
import '../../../../core/drift/providers/database_provider.dart';

class DashboardUserMenu extends StatelessWidget {
  const DashboardUserMenu({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          const _FamilyChatButton(),
        IconButton(
          tooltip: context.lang.settingsTitle,
          iconSize: 26,
          icon: const Icon(Icons.settings_outlined),
          onPressed: () => context.router.pushPath('/settings'),
        ),
      ],
    );
  }
}

class _FamilyChatButton extends ConsumerStatefulWidget {
  const _FamilyChatButton();
  @override
  ConsumerState<_FamilyChatButton> createState() => _FamilyChatButtonState();
}

class _FamilyChatButtonState extends ConsumerState<_FamilyChatButton> {
  Future<List<FamilyChatFoodChoice>> _loadFoods() async {
    final db = ref.read(databaseProvider);
    final items = await db.quickLowTreatmentItemDao.getQuickLowTreatmentItems();
    return [
      for (final item in items)
        if (item.portion == null ||
            (item.gramsPerPortion != null && item.gramsPerPortion! > 0))
          FamilyChatFoodChoice(
            name: item.name,
            unit: item.ingredient.isReference
                ? 'porcji'
                : item.portion?.name ?? 'g',
            initialAmount: item.amount,
            gramsPerUnit: item.ingredient.isReference
                ? null
                : item.portion != null
                ? item.gramsPerPortion
                : 1,
            carbsPerUnit:
                calculateNetCarbs(
                  carbs: item.ingredient.carbsPer100g,
                  fiber: item.ingredient.fiberPer100g,
                  labelMode: item.ingredient.carbsLabelMode,
                ) *
                (item.ingredient.isReference
                    ? 1
                    : item.portion != null
                    ? item.gramsPerPortion! / 100
                    : .01),
          ),
    ];
  }

  Future<FamilyChatFoodChoice?> _pickIngredient(BuildContext context) async {
    final language = Localizations.localeOf(context).languageCode;
    final selected = await showIngredientCatalogPicker(
      context,
      searchOnly: true,
    );
    if (selected == null || !mounted) return null;
    if (selected.localIngredientId != null) {
      final ingredient =
          (await ref
                  .read(databaseProvider)
                  .ingredientDao
                  .getIngredientById(selected.localIngredientId!))
              .toDomain();
      return FamilyChatFoodChoice(
        name: ingredient.name,
        unit: ingredient.isReference ? 'porcji' : 'g',
        gramsPerUnit: ingredient.isReference ? null : 1,
        carbsPerUnit:
            calculateNetCarbs(
              carbs: ingredient.carbsPer100g,
              fiber: ingredient.fiberPer100g,
              labelMode: ingredient.carbsLabelMode,
            ) *
            (ingredient.isReference ? 1 : .01),
      );
    }
    final ingredient = await ref
        .read(catalogRepositoryProvider)
        .get(selected.identity, languageCode: language);
    return FamilyChatFoodChoice(
      name: ingredient.name,
      unit: 'g',
      gramsPerUnit: 1,
      carbsPerUnit: ingredient.netCarbsPer100g / 100,
    );
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(familyChatRuntimeProvider);
    final settings = ref.watch(familyChatSettingsRuntimeProvider);
    final preferences = ref.watch(familyChatPreferencesProvider);
    return ListenableBuilder(
      listenable: Listenable.merge([runtime, if (settings != null) settings]),
      builder: (context, _) {
        final session = runtime.session;
        final state = settings?.controller.state;
        final accountEnabled =
            state?['account']?['changes']?['accountEnabled'] as bool? ??
            state?['confirmed']?['account']?['enabled'] as bool? ??
            preferences.enabled;
        if (!accountEnabled) return const SizedBox.shrink();
        final hasUnread = (session?.unreadCount ?? 0) > 0;
        final senderName = !hasUnread || session?.unreadSender == null
            ? ''
            : session!.name(session.unreadSender!).trim();
        return IconButton(
          tooltip: 'Rozmowy rodzinne',
          icon: Badge(
            isLabelVisible: hasUnread,
            label: Text(senderName.isEmpty ? '' : senderName.characters.first),
            backgroundColor: const Color(0xFF0EA5E9),
            child: const Icon(LucideIcons.messagesSquare, size: 26),
          ),
          onPressed: () {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => FamilyChatPage(
                  loadFoods: _loadFoods,
                  pickIngredient: _pickIngredient,
                ),
              ),
            );
          },
        );
      },
    );
  }
}
