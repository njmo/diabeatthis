import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/language.dart';
import '../application/family_chat_runtime.dart';
import '../application/family_chat_session.dart';
import '../application/family_chat_settings_runtime.dart';
import '../application/family_treatment_adapter.dart';
import 'family_chat_conversation.dart';

class FamilyChatPage extends ConsumerStatefulWidget {
  const FamilyChatPage({
    super.key,
    this.loadFoods,
    this.pickIngredient,
    this.initialTarget,
  });
  final String? initialTarget;
  final Future<List<FamilyChatFoodChoice>> Function()? loadFoods;
  final Future<FamilyChatFoodChoice?> Function(BuildContext)? pickIngredient;
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
          loadFoods: widget.loadFoods,
          pickIngredient: widget.pickIngredient,
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
    this.loadFoods,
    this.pickIngredient,
  });
  final FamilyChatSession session;
  final String? initialTarget;
  final Future<List<FamilyChatFoodChoice>> Function()? loadFoods;
  final Future<FamilyChatFoodChoice?> Function(BuildContext)? pickIngredient;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final executor = session.isCaregiver
        ? null
        : ref.watch(familyTreatmentExecutorProvider(session));
    return FamilyChatConversation(
      isCaregiver: session.isCaregiver,
      session: session,
      initialTarget: initialTarget,
      loadFoods: loadFoods,
      pickIngredient: pickIngredient,
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
