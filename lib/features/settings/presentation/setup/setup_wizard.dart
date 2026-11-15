import 'package:flutter/material.dart';

import '../../../../common/auth/google_authentication_repository.dart';
import '../../../../common/family/family_management_context.dart';
import '../../../../common/family/family_pairing_repository.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/l10n/resolve_application_locale.dart';
import '../../../../common/setup/domain/setup_account_choice.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/setup/domain/setup_permission_gateway.dart';
import '../../../../common/setup/domain/setup_step.dart';
import '../../../../common/setup/domain/validate_setup_module_use_case.dart';
import '../../../../common/widgets/form_step_header.dart';
import '../../../../common/widgets/show_localized_dialog.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import 'setup_labels.dart';
import 'setup_wizard_controller.dart';
import 'setup_wizard_state.dart';
import 'steps/setup_access_step.dart';
import 'steps/setup_ai_module.dart';
import 'steps/setup_data_module.dart';
import 'steps/setup_family_module.dart';
import 'steps/setup_feature_options_module.dart';
import 'steps/setup_features_step.dart';
import 'steps/setup_meal_advisor_module.dart';
import 'steps/setup_nightscout_module.dart';
import 'steps/setup_role_step.dart';
import 'steps/setup_start_step.dart';
import 'steps/setup_summary_step.dart';
import 'widgets/setup_language_control.dart';
import 'widgets/setup_step_heading.dart';
import 'widgets/setup_wizard_actions.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({
    super.key,
    required this.initialState,
    required this.availability,
    this.onSavePatient,
    this.onSaveCaregiver,
    this.familyRepository,
    this.familyContext = FamilyManagementContext.settings,
    this.saving = false,
    this.saveError,
    this.authentication,
    this.permissions,
    this.checkNightscoutConnection,
  });
  final SetupWizardState initialState;
  final DataSourceOptionAvailability availability;
  final Future<bool> Function(SetupWizardState draft)? onSavePatient;
  final Future<bool> Function(SetupWizardState draft)? onSaveCaregiver;
  final FamilyManagementContext familyContext;
  final FamilyPairingRepository? familyRepository;
  final bool saving;
  final String? saveError;
  final GoogleAuthenticationRepository? authentication;
  final SetupPermissionGateway? permissions;
  final SetupConnectionValidator? checkNightscoutConnection;

  @override
  State<SetupWizard> createState() => SetupWizardViewState();
}

class SetupWizardViewState extends State<SetupWizard>
    with WidgetsBindingObserver {
  late final controller = SetupWizardController(
    widget.initialState,
    familyRepository: widget.familyRepository,
    familyContext: widget.familyContext,
    authentication: widget.authentication,
    permissions: widget.permissions,
    checkNightscoutConnection: widget.checkNightscoutConnection,
  );
  bool allowExit = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.refreshPermissions();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) controller.refreshPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    controller.dispose();
    super.dispose();
  }

  void back() {
    FocusScope.of(context).unfocus();
    controller.back();
  }

  Future<void> exitPreview() async {
    if (widget.onSavePatient != null || !Navigator.of(context).canPop()) {
      controller.goTo(0);
      return;
    }
    setState(() => allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> skip(BuildContext context) async {
    if (controller.module == SetupModule.nightscout &&
        controller.state.config.usesCloud) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.lang.setupNightscoutCannotSkip)),
      );
      controller.state.moduleIndex = controller.modules
          .indexOf(SetupModule.data)
          .clamp(0, controller.modules.length - 1);
      controller.goTo(SetupStep.configuration.index);
      return;
    }
    final confirmed = await showLocalizedDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.lang.setupSkipTitle),
        content: Text(
          controller.module == SetupModule.nightscout
              ? context.lang.setupSkipNightscoutOptions
              : context.lang.setupSkipDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.lang.setupBack),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.lang.setupSkipConfirm),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) controller.skipModule();
  }

  Future<void> next(BuildContext context) async {
    FocusScope.of(context).unfocus();
    if (controller.state.currentStep == SetupStep.start &&
        controller.authentication != null &&
        !controller.state.signedIn) {
      await controller.continueWithoutGoogle();
      if (!context.mounted ||
          controller.state.signInFailed ||
          controller.state.accountChoice != SetupAccountChoice.local) {
        return;
      }
    }
    final incompleteConfiguration =
        controller.incompleteRequiredConfigurationModule;
    if (controller.state.currentStep == SetupStep.summary &&
        incompleteConfiguration != null) {
      controller.state.moduleIndex = controller.modules.indexOf(
        incompleteConfiguration,
      );
      controller.goTo(SetupStep.configuration.index);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.missingConfiguration.isEmpty
                ? context.lang.setupModuleIncomplete
                : context.lang.setupRequiredFieldsMissing(
                    controller.missingConfiguration
                        .map(context.lang.configurationFieldName)
                        .join(', '),
                  ),
          ),
        ),
      );
      return;
    }
    if (controller.state.currentStep == SetupStep.summary) {
      if (widget.onSavePatient != null &&
          controller.state.mode == SetupDeviceMode.patient) {
        await widget.onSavePatient!(controller.state);
      } else if (widget.onSaveCaregiver != null &&
          controller.state.mode == SetupDeviceMode.caregiver) {
        await widget.onSaveCaregiver!(controller.state);
      } else {
        await showLocalizedDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.lang.setupPreviewFinished),
            content: Text(context.lang.setupLiveConfigurationFinished),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.lang.setupUnderstood),
              ),
            ],
          ),
        );
        if (mounted) await exitPreview();
      }
      return;
    }
    if (!await controller.validateAndNext() && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            (controller.state.currentStep == SetupStep.start ||
                    controller.state.currentStep == SetupStep.role)
                ? context.lang.setupChooseAccountFirst
                : controller.state.currentStep == SetupStep.access
                ? context.lang.setupPermissionsIncomplete
                : controller.missingConfiguration.any(
                    (field) => field.module == controller.module,
                  )
                ? context.lang.setupRequiredFieldsMissing(
                    controller.missingConfiguration
                        .where((field) => field.module == controller.module)
                        .map(context.lang.configurationFieldName)
                        .join(', '),
                  )
                : context.lang.setupModuleIncomplete,
          ),
        ),
      );
    }
  }

  Widget contentForStep(
    BuildContext context,
  ) => switch (controller.state.currentStep) {
    SetupStep.start => SetupStartStep(
      controller: controller,
      enableProfilePhoto: widget.onSavePatient != null,
    ),
    SetupStep.role => SetupRoleStep(controller: controller),
    SetupStep.features => SetupFeaturesStep(controller: controller),
    SetupStep.access => SetupAccessStep(controller: controller),
    SetupStep.configuration => switch (controller.module) {
      SetupModule.data => SetupDataModule(
        controller: controller,
        availability: widget.availability,
      ),
      SetupModule.family => SetupFamilyModule(controller: controller),
      SetupModule.mealAdvisor => SetupMealAdvisorModule(controller: controller),
      SetupModule.ai => SetupAiModule(controller: controller),
      SetupModule.activity || SetupModule.lowTreatment =>
        SetupFeatureOptionsModule(controller: controller),
      SetupModule.nightscout => SetupNightscoutModule(controller: controller),
      null => SetupStepHeading(
        title: context.lang.setupModulesEmpty,
        description: context.lang.setupSummaryDescription,
      ),
    },
    SetupStep.summary => SetupSummaryStep(
      controller: controller,
      canSavePatient:
          widget.onSavePatient != null &&
          controller.state.mode == SetupDeviceMode.patient,
    ),
  };

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) => Localizations.override(
      context: context,
      locale: resolveApplicationLocale(
        controller.state.language,
        systemLocales: WidgetsBinding.instance.platformDispatcher.locales,
      ),
      child: Builder(builder: buildWizard),
    ),
  );

  Widget buildWizard(BuildContext context) {
    final state = controller.state;
    final inModule =
        state.currentStep == SetupStep.configuration &&
        controller.module != null;
    final busy = widget.saving || controller.isValidating || state.signingIn;
    final savePatient =
        widget.onSavePatient != null && state.mode == SetupDeviceMode.patient;
    final header = inModule
        ? context.lang.setupConfigurationProgress(
            state.moduleIndex + 1,
            controller.modules.length,
          )
        : context.lang.setupTitle;
    return PopScope(
      canPop: allowExit || (state.step == 0 && !busy),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !busy) back();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
            SetupLanguageControl(controller: controller),
            if (widget.onSavePatient == null && Navigator.of(context).canPop())
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: exitPreview,
                icon: const Icon(Icons.close),
              ),
          ],
          title: Text(header),
          leading: state.step > 0
              ? IconButton(
                  tooltip: context.lang.setupBack,
                  onPressed: busy ? null : back,
                  icon: const Icon(Icons.arrow_back),
                )
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: FormStepHeader(
                  labels: [
                    context.lang.setupStepStart,
                    context.lang.setupStepRole,
                    context.lang.setupStepFeatures,
                    context.lang.setupStepAccess,
                    inModule
                        ? context.lang.moduleName(controller.module)
                        : context.lang.setupConfigurationStepLabel,
                    context.lang.setupStepDone,
                  ],
                  currentStep: state.step,
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  key: ValueKey((state.step, state.moduleIndex)),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      contentForStep(context),
                      if (widget.saveError != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text(
                            widget.saveError!,
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: SetupWizardActions(
          saving: busy,
          onNext:
              inModule &&
                  controller.module == SetupModule.ai &&
                  !controller.aiSubmission.isReady
              ? null
              : () => next(context),
          onPreviousFeature: inModule && state.moduleIndex > 0 ? back : null,
          onSkip: inModule && controller.canSkipCurrentModule
              ? () => skip(context)
              : null,
          label:
              state.currentStep == SetupStep.start &&
                  controller.authentication != null &&
                  !state.signedIn
              ? context.lang.setupContinueWithoutGoogle
              : state.currentStep == SetupStep.summary
              ? (savePatient
                    ? context.lang.setupPatientSave
                    : widget.onSaveCaregiver != null
                    ? context.lang.setupCaregiverSave
                    : context.lang.setupFinishPreview)
              : context.lang.setupNext,
        ),
      ),
    );
  }
}
