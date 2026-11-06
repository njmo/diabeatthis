import 'dart:async';

import 'package:diabeatthis/common/family/demo_family_pairing_repository.dart';
import 'package:diabeatthis/common/family/family_management_context.dart';
import 'package:diabeatthis/common/l10n/application_language.dart';
import 'package:diabeatthis/common/setup/domain/setup_feature.dart';
import 'package:diabeatthis/core/data_sources/config/data_source_config.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_controller.dart';
import 'package:diabeatthis/features/settings/presentation/setup/setup_wizard_state.dart';
import 'package:diabeatthis/features/settings/presentation/setup/widgets/setup_family_pairing_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/localized_material_app.dart';

SetupWizardState familyManagementDraft() => SetupWizardState(
  config: const DataSourceConfig.defaults(),
  language: applicationLanguageByCode('pl'),
  name: 'Demo',
  nightscoutUrl: '',
  nightscoutToken: '',
);

class PendingFamilyDisconnectRepository extends DemoFamilyPairingRepository {
  final completion = Completer<void>();
  int calls = 0;
  @override
  Future<void> disconnectMember(
    SetupDeviceMode mode,
    String memberId,
    FamilyManagementContext context,
  ) {
    calls++;
    return completion.future;
  }
}

void main() {
  for (final context in FamilyManagementContext.values) {
    testWidgets('patient family list supports disconnection only in $context', (
      tester,
    ) async {
      final state = familyManagementDraft();
      final controller = SetupWizardController(state, familyContext: context);
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        localizedMaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SetupFamilyPairingPanel(controller: controller),
            ),
          ),
        ),
      );
      controller.simulateSignIn();
      await tester.pumpAndSettle();
      controller.simulatePairing();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pump(const Duration(milliseconds: 240));
      await tester.pumpAndSettle();
      expect(find.text('Opiekunowie'), findsOneWidget);
      expect(find.text('Dodaj opiekuna'), findsOneWidget);
      final remove = find.byTooltip('Odłącz Alex Morgan');
      if (context == FamilyManagementContext.settings) {
        expect(remove, findsNothing);
        await controller.disconnectMember(state.familyMembers.single.id);
        expect(state.familyMembers, hasLength(1));
      } else {
        await tester.ensureVisible(remove);
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Anuluj'));
        await tester.pumpAndSettle();
        expect(state.familyMembers, hasLength(1));
        await tester.tap(remove);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Odłącz'));
        await tester.pumpAndSettle();
        expect(state.familyMembers, isEmpty);
        expect(state.paired, isFalse);
        expect(state.configured.contains(SetupModule.family), isFalse);
        expect(find.text('Alex Morgan'), findsNothing);
        await tester.ensureVisible(find.text('Dodaj opiekuna'));
        await tester.tap(find.text('Dodaj opiekuna'));
        await tester.pumpAndSettle();
        expect(find.byIcon(Icons.qr_code_2), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
  test('failed disconnection retains members and can be retried', () async {
    final repository = PendingFamilyDisconnectRepository();
    addTearDown(repository.dispose);
    final controller = SetupWizardController(
      familyManagementDraft()..mode = SetupDeviceMode.caregiver,
      familyRepository: repository,
    );
    addTearDown(controller.dispose);
    controller.simulateSignIn();
    await Future<void>.delayed(Duration.zero);
    controller.simulatePairing();
    final id = controller.state.familyMembers.single.id;
    final pending = controller.disconnectMember(id);
    await controller.disconnectMember(id);
    expect(repository.calls, 1);
    repository.completion.completeError(StateError('offline'));
    await pending;
    expect(controller.state.familyMembers, hasLength(1));
    expect(controller.state.disconnectFailed, isTrue);
    expect(controller.state.disconnectingMembers, isEmpty);
  });
  test('mode changes ignore stale disconnection failures', () async {
    final repository = PendingFamilyDisconnectRepository();
    addTearDown(repository.dispose);
    final controller = SetupWizardController(
      familyManagementDraft()..mode = SetupDeviceMode.caregiver,
      familyRepository: repository,
    );
    addTearDown(controller.dispose);
    controller.simulateSignIn();
    await Future<void>.delayed(Duration.zero);
    controller.simulatePairing();
    final pending = controller.disconnectMember(
      controller.state.familyMembers.single.id,
    );
    controller.setMode(SetupDeviceMode.patient);
    repository.completion.completeError(StateError('offline'));
    await pending;
    expect(controller.state.disconnectFailed, isFalse);
    expect(controller.state.disconnectingMembers, isEmpty);
  });
}
