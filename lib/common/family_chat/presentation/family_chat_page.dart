import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/domain/model/net_carbs_calculator.dart';
import '../../family/family_providers.dart';
import '../../family_sync/load_child_ingredient_mirror.dart';
import '../../family_sync/photo/family_photo_ingredient_reader.dart';
import '../../family_sync/presentation/show_family_ingredient_picker.dart';
import '../../ingredient_catalog/ingredient_catalog_providers.dart';
import '../../l10n/language.dart';
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

class _FamilyChatPageState extends ConsumerState<FamilyChatPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    ref.read(familyChatRuntimeProvider).setChatVisible(false);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => ref
      .read(familyChatRuntimeProvider)
      .setForeground(state == AppLifecycleState.resumed);
  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(familyChatRuntimeProvider);
    final current = ModalRoute.of(context)?.isCurrent == true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runtime.setChatVisible(current);
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

class _ConnectedFamilyChat extends ConsumerWidget {
  const _ConnectedFamilyChat({
    super.key,
    required this.session,
    this.initialTarget,
  });
  final FamilyChatSession session;
  final String? initialTarget;
  Future<FamilyChatFoodChoice?> _pickIngredient(
    BuildContext context,
    WidgetRef ref,
    String target,
  ) async {
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
    final transport = ref.read(authenticatedFamilyTransportProvider);
    final catalog = ref.read(catalogRepositoryProvider);
    final language = Localizations.localeOf(context).languageCode;
    final rows = await loadChildIngredientMirror(
      transport: transport,
      caregiverUid: session.uid,
      childUid: child,
      isCurrent: isCurrent,
    );
    if (!context.mounted || !isCurrent()) return null;
    final selected = await showFamilyIngredientPicker(
      context,
      rows: rows,
      catalog: catalog,
    );
    if (selected == null || !isCurrent()) return null;

    final id = selected.localIngredientId;
    if (id != null) {
      final ingredient = await FamilyPhotoIngredientReader(rows).get(id);
      if (!isCurrent()) return null;
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
    final ingredient = await catalog.get(
      selected.identity,
      languageCode: language,
    );
    if (!isCurrent()) return null;
    return FamilyChatFoodChoice(
      name: ingredient.name,
      unit: 'g',
      gramsPerUnit: 1,
      carbsPerUnit: ingredient.netCarbsPer100g / 100,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (session.isCaregiver) ref.watch(authenticatedFamilyTransportProvider);
    final executor = session.isCaregiver
        ? null
        : ref.watch(familyTreatmentExecutorProvider(session));
    return FamilyChatConversation(
      isCaregiver: session.isCaregiver,
      session: session,
      initialTarget: initialTarget,
      pickIngredient: session.isCaregiver
          ? (context, target) => _pickIngredient(context, ref, target)
          : null,
      confirmTreatment: executor?.confirm,
      confirmTreatmentWithAuthorization: executor == null
          ? null
          : (id, quantity, authorization) => executor.confirm(
              id,
              actualQuantity: quantity,
              acceptedAuthorization: authorization,
            ),
      confirmTreatmentQuantity: executor == null
          ? null
          : (id, quantity) => executor.confirm(id, actualQuantity: quantity),
      loadTreatmentResult: executor?.lookup,
      loadTreatmentQuantity: executor?.lookupQuantity,
    );
  }
}
