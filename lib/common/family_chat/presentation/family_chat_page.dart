import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/net_carbs_calculator.dart';
import '../../../core/drift/providers/database_provider.dart';
import '../../../core/notifications/domain/events/family_chat_notification.dart';
import '../../../core/notifications/providers/notifications_controller_provider.dart';
import '../../../features/low_treatment/data/providers/low_treatment_aaps_provider.dart';
import '../../backend/authenticated_callable_transport.dart';
import '../../family/family_providers.dart';
import '../../family_sync/child_ingredient_search_repository.dart';
import '../../family_sync/edit_family_quick_treatment_use_case.dart';
import '../../family_sync/family_plan_submission_store.dart';
import '../../family_sync/presentation/family_quick_treatment_editor.dart';
import '../../family_sync/presentation/models/family_ingredient_view.dart';
import '../../family_sync/presentation/show_family_ingredient_picker.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../l10n/language.dart';
import '../../planning/caregiver_meal_form_actions.dart';
import '../../platform/aaps_launcher.dart';
import '../application/family_chat_background.dart';
import '../application/family_chat_runtime.dart';
import '../application/family_chat_session.dart';
import '../application/family_chat_settings_runtime.dart';
import '../application/family_treatment_adapter.dart';
import 'family_chat_conversation.dart';

class FamilyChatPage extends ConsumerStatefulWidget {
  const FamilyChatPage({super.key, this.initialTarget});
  final String? initialTarget;
  @override
  ConsumerState<FamilyChatPage> createState() => _FamilyChatPageState();
}

class _FamilyChatPageState extends ConsumerState<FamilyChatPage> {
  FamilyChatRuntime? _runtime;
  ModalRoute<dynamic>? _chatRoute;

  @override
  void dispose() {
    if (_chatRoute case final route?) _runtime?.forgetChatRoute(route);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(familyChatRuntimeProvider);
    final route = ModalRoute.of(context);
    _runtime = runtime;
    _chatRoute = route;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          identical(_runtime, runtime) &&
          route != null &&
          route.isActive) {
        runtime.trackChatRoute(route);
      }
    });
    return ListenableBuilder(
      listenable: runtime,
      builder: (context, _) {
        final session = runtime.session;
        if (session == null || session.config == null || !session.enabled) {
          return Scaffold(
            appBar: AppBar(title: Text(context.lang.familyChatNavTitle)),
            body: Center(
              child: session?.busy == true
                  ? const CircularProgressIndicator()
                  : Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            session?.error == null
                                ? context.lang.familyChatDisabledOrNotConnected
                                : context.lang.familyChatConnectionFailed,
                          ),
                          TextButton.icon(
                            onPressed: () async {
                              await ref
                                  .read(familyChatSettingsRuntimeProvider)
                                  ?.pump();
                              await runtime.session?.synchronize();
                            },
                            icon: const Icon(Icons.refresh),
                            label: Text(context.lang.commonRetry),
                          ),
                        ],
                      ),
                    ),
            ),
          );
        }
        return _ConnectedFamilyChat(
          key: ValueKey(session),
          session: session,
          initialTarget: widget.initialTarget,
        );
      },
    );
  }
}

Future<void> showFamilyLowTreatmentFromDashboard(
  BuildContext context,
  WidgetRef ref,
) async {
  final session = ref.read(familyChatRuntimeProvider).session;
  final target = session?.members
      .where((member) => member['role'] == 'child')
      .firstOrNull?['uid'];
  if (session == null ||
      !session.serverVerified ||
      !session.isCaregiver ||
      target is! String) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.lang.familyChatDisabledOrNotConnected)),
    );
    return;
  }
  final actions = _FamilyLowTreatmentActions(session);
  var quickFoods = (foods: const <FamilyChatFoodChoice>[], canEdit: false);
  try {
    quickFoods = await actions.loadQuickFoods(context, ref, target);
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.lang.familyChatLoadFoodsFailed)),
    );
  }
  if (!context.mounted ||
      !session.serverVerified ||
      !session.isCurrentAccount()) {
    return;
  }
  final scope = session.scope;
  final generation = session.historyGeneration;
  final messageId = await showFamilyLowTreatmentComposer(
    context,
    session: session,
    target: target,
    foods: quickFoods.foods,
    onEdit: quickFoods.canEdit
        ? () => actions.editQuickFoods(context, ref, target)
        : null,
    pickIngredient: (sheetContext) =>
        actions.pickIngredient(sheetContext, ref, target),
  );
  if (!context.mounted ||
      messageId == null ||
      scope == null ||
      session.scope != scope ||
      session.historyGeneration != generation) {
    return;
  }
  final notice = familyChatNotice(scope, messageId);
  await ref
      .read(notificationsControllerUiProvider)
      .show(
        FamilyChatNotificationEvent(
          id: notice.id,
          tag: notice.tag,
          title: context.lang.familyChatTreatmentAddedToConversation,
          body: '',
          payload: {
            'type': 'familyChat',
            'uid': session.uid,
            'scope': scope,
            'messageId': messageId,
            'historyGeneration': generation,
          },
          openRequest: true,
          timeoutAfter: 5000,
          transient: true,
        ),
      );
}

class _FamilyLowTreatmentActions {
  const _FamilyLowTreatmentActions(this.session);
  final FamilyChatSession session;
  ChildIngredientSearchRepository _childIngredientSource(
    BuildContext context,
    WidgetRef ref,
    String target,
  ) {
    final scope = session.scope;
    final children = session.members.where(
      (member) => member['role'] == 'child',
    );
    final child = target == 'family'
        ? children.length == 1
              ? children.single['uid'] as String?
              : null
        : children
                  .where((member) => member['uid'] == target)
                  .firstOrNull?['uid']
              as String?;
    bool isCurrent() =>
        context.mounted &&
        scope != null &&
        session.scope == scope &&
        session.serverVerified &&
        session.isCurrentAccount() &&
        session.members.any(
          (member) => member['role'] == 'child' && member['uid'] == child,
        );
    if (child == null || !isCurrent()) {
      throw StateError('A child conversation is required');
    }
    return ChildIngredientSearchRepository(
      transport: ref.read(authenticatedFamilyTransportProvider),
      caregiverUid: session.uid,
      childUid: child,
      isCurrent: isCurrent,
    );
  }

  Future<({List<FamilyChatFoodChoice> foods, bool canEdit})> loadQuickFoods(
    BuildContext context,
    WidgetRef ref,
    String target,
  ) async {
    final source = _childIngredientSource(context, ref, target);
    final response = await source.quickFoods();
    if (!source.isCurrent()) {
      return (foods: const <FamilyChatFoodChoice>[], canEdit: false);
    }
    final foods = response.items.map((row) {
      final ingredient = familyIngredientView(row['ingredient'] as Map);
      final weight = (row['gramsPerUnit'] as num?)?.toDouble();
      final carbs = calculateNetCarbs(
        carbs: ingredient.carbsPer100g,
        fiber: ingredient.fiberPer100g,
        labelMode: ingredient.carbsLabelMode,
      );
      return FamilyChatFoodChoice(
        name: row['name'] as String,
        iconAssetPath: ingredient.iconAssetPath,
        unit: weight == null ? 'portion' : 'piece',
        gramsPerUnit: weight,
        carbsPerUnit: weight == null ? carbs : weight * carbs / 100,
        initialAmount: (row['amount'] as num).toDouble(),
        quickShortcut: true,
      );
    }).toList();
    return (foods: foods, canEdit: response.canEdit);
  }

  Future<void> editQuickFoods(
    BuildContext context,
    WidgetRef ref,
    String target,
  ) async {
    final source = _childIngredientSource(context, ref, target);
    final catalog = ref.read(catalogRepositoryProvider);
    final edit = EditFamilyQuickTreatmentUseCase(
      source,
      FamilyPlanSubmissionStore(ref.read(databaseProvider)),
    );
    try {
      final snapshot = await edit.load();
      if (!context.mounted || !source.isCurrent()) return;
      if (snapshot.pending) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.lang.familyPlanPending)));
        return;
      }
      final rows = {
        for (final row in snapshot.rows) '${row['kind']}/${row['id']}': row,
      };
      final items = await showFamilyQuickTreatmentEditor(
        context,
        rows: snapshot.rows,
        pickIngredient: (pickerContext) async {
          final selected = await showFamilyIngredientSearchPicker(
            pickerContext,
            local: source,
            catalog: catalog,
            queryDebounce: const Duration(milliseconds: 500),
          );
          if (selected == null ||
              !pickerContext.mounted ||
              !source.isCurrent()) {
            return null;
          }
          final id = selected.localIngredientId;
          if (id == null) {
            ScaffoldMessenger.of(pickerContext).showSnackBar(
              SnackBar(
                content: Text(
                  pickerContext.lang.familyQuickTreatmentChoosePortion,
                ),
              ),
            );
            return null;
          }
          final details = await edit.ingredientRows(id, snapshot.sourceId);
          if (!pickerContext.mounted ||
              !context.mounted ||
              !source.isCurrent()) {
            return null;
          }
          final actions = CaregiverMealFormActions(
            rows: details,
            catalog: catalog,
          );
          try {
            final draft = await actions.pickIngredient(
              pickerContext,
              ref,
              selection: selected,
            );
            if (draft != null) {
              for (final row in details) {
                rows.putIfAbsent('${row['kind']}/${row['id']}', () => row);
              }
            }
            return draft;
          } finally {
            actions.dispose();
          }
        },
      );
      if (items == null || !source.isCurrent()) return;
      await edit.save(
        sourceId: snapshot.sourceId,
        rows: rows.values.toList(),
        items: items,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.lang.familyPlanPending)));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.lang.quickLowTreatmentSaveError)),
        );
      }
    }
  }

  Future<FamilyChatFoodChoice?> pickIngredient(
    BuildContext context,
    WidgetRef ref,
    String target,
  ) async {
    final local = _childIngredientSource(context, ref, target);
    final catalog = ref.read(catalogRepositoryProvider);
    final language = Localizations.localeOf(context).languageCode;
    final selected = await showFamilyIngredientSearchPicker(
      context,
      local: local,
      catalog: catalog,
      queryDebounce: const Duration(milliseconds: 500),
    );
    if (selected == null || !local.isCurrent()) return null;

    if (selected is ChildIngredientSearchItem) {
      final ingredient = selected.ingredient;
      double? gramsPerPiece;
      if (!ingredient.isReference) {
        try {
          gramsPerPiece = await local.gramsPerPiece(ingredient.id);
        } on CallableFailure {
          // The caregiver can supply the weight when the lookup fails.
        }
      }
      if (!local.isCurrent()) return null;
      return FamilyChatFoodChoice(
        name: ingredient.name,
        unit: ingredient.isReference ? 'porcji' : 'g',
        gramsPerUnit: gramsPerPiece,
        carbsPerUnit:
            calculateNetCarbs(
              carbs: ingredient.carbsPer100g,
              fiber: ingredient.fiberPer100g,
              labelMode: ingredient.carbsLabelMode,
            ) *
            (ingredient.isReference ? 1 : .01),
      );
    }
    final ingredient = await catalog.get(
      selected.identity,
      languageCode: language,
    );
    if (!local.isCurrent()) return null;
    return FamilyChatFoodChoice(
      name: ingredient.name,
      unit: 'g',
      carbsPerUnit: ingredient.netCarbsPer100g / 100,
    );
  }
}

class _ConnectedFamilyChat extends ConsumerWidget {
  const _ConnectedFamilyChat({
    super.key,
    required this.session,
    this.initialTarget,
  });
  final FamilyChatSession session;
  final String? initialTarget;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.isCaregiver) ref.watch(authenticatedFamilyTransportProvider);
    final executor = session.isCaregiver
        ? null
        : ref.watch(familyTreatmentExecutorProvider(session));
    Future<void> openAaps(int mealId) async {
      if (!context.mounted) return;
      try {
        final result = await ref
            .read(lowTreatmentAapsControllerProvider)
            .open(mealId, context.lang);
        if (result == AapsLaunchResult.opened) return;
      } catch (_) {
        // Consumption is already saved. Keep the error scoped to the handoff.
      }
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(context.lang.aapsOpenFailed)));
      }
    }

    return FamilyChatConversation(
      isCaregiver: session.isCaregiver,
      session: session,
      initialTarget: initialTarget,
      showTreatmentAction: false,
      confirmTreatment: executor == null
          ? null
          : (id) => executor.confirm(id, onSaved: openAaps),
      confirmTreatmentWithAuthorization: executor == null
          ? null
          : (id, quantity, authorization) => executor.confirm(
              id,
              actualQuantity: quantity,
              acceptedAuthorization: authorization,
              onSaved: openAaps,
            ),
      confirmTreatmentQuantity: executor == null
          ? null
          : (id, quantity) => executor.confirm(
              id,
              actualQuantity: quantity,
              onSaved: openAaps,
            ),
      loadTreatmentResult: executor?.lookup,
      loadTreatmentQuantity: executor?.lookupQuantity,
    );
  }
}
