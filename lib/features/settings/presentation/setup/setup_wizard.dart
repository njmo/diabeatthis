import 'package:flutter/material.dart';

import '../../../../common/family/family_management_context.dart';
import '../../../../common/l10n/language.dart';
import '../../../../common/l10n/resolve_application_locale.dart';
import '../../../../common/setup/domain/setup_feature.dart';
import '../../../../common/widgets/form_step_header.dart';
import '../../../../common/widgets/show_localized_dialog.dart';
import '../../../../core/data_sources/config/data_source_option_availability.dart';
import 'setup_labels.dart';
import 'setup_wizard_controller.dart';
import 'setup_wizard_state.dart';
import 'steps/setup_access_step.dart';
import 'steps/setup_ai_module.dart';
import 'steps/setup_basics_step.dart';
import 'steps/setup_data_step.dart';
import 'steps/setup_family_module.dart';
import 'steps/setup_feature_options_module.dart';
import 'steps/setup_features_step.dart';
import 'steps/setup_nightscout_module.dart';
import 'steps/setup_summary_step.dart';
import 'widgets/setup_notice.dart';
import 'widgets/setup_step_heading.dart';
import 'widgets/setup_wizard_actions.dart';

class SetupWizard extends StatefulWidget {
  const SetupWizard({
    super.key,
    required this.initialState,
    required this.availability,
    this.onSavePatient,
    this.familyContext = FamilyManagementContext.settings,
    this.saving = false,
    this.saveError,
  });
  final SetupWizardState initialState;
  final DataSourceOptionAvailability availability;
  final Future<bool> Function(SetupWizardState draft)? onSavePatient;
  final FamilyManagementContext familyContext;
  final bool saving;
  final String? saveError;

  @override
  State<SetupWizard> createState() => SetupWizardViewState();
}

class SetupWizardViewState extends State<SetupWizard> {
  late final controller = SetupWizardController(
    widget.initialState,
    familyContext: widget.familyContext,
  );
  bool allowExit = false;
  @override
  void dispose() {
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
      controller.goTo(2);
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
    final incompleteConfiguration =
        controller.incompleteRequiredConfigurationModule;
    if (controller.state.step == 5 && incompleteConfiguration != null) {
      controller.state.moduleIndex = controller.modules.indexOf(
        incompleteConfiguration,
      );
      controller.goTo(4);
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
    if (controller.state.step == 5) {
      if (widget.onSavePatient != null &&
          controller.state.mode == SetupDeviceMode.patient) {
        await widget.onSavePatient!(controller.state);
      } else {
        await showLocalizedDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(context.lang.setupPreviewFinished),
            content: Text(context.lang.setupPreviewFinishedDescription),
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
    if (!controller.next() && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            controller.missingConfiguration.any(
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

  Widget contentForStep(BuildContext context) =>
      switch (controller.state.step) {
        0 => SetupBasicsStep(
          controller: controller,
          enableProfilePhoto:
              widget.onSavePatient != null &&
              controller.state.mode == SetupDeviceMode.patient,
        ),
        1 => SetupFeaturesStep(controller: controller),
        2 => SetupDataStep(
          controller: controller,
          availability: widget.availability,
        ),
        3 => SetupAccessStep(controller: controller),
        4 => switch (controller.module) {
          SetupModule.family => SetupFamilyModule(controller: controller),
          SetupModule.ai => SetupAiModule(controller: controller),
          SetupModule.activity || SetupModule.lowTreatment =>
            SetupFeatureOptionsModule(controller: controller),
          SetupModule.nightscout => SetupNightscoutModule(
            controller: controller,
          ),
          null => SetupStepHeading(
            title: context.lang.setupModulesEmpty,
            description: context.lang.setupSummaryDescription,
          ),
        },
        _ => SetupSummaryStep(
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
      locale: resolveApplicationLocale(controller.state.language),
      child: Builder(builder: buildWizard),
    ),
  );

  Widget buildWizard(BuildContext context) {
    final state = controller.state;
    final inModule = state.step == 4 && controller.module != null;
    final savePatient =
        widget.onSavePatient != null && state.mode == SetupDeviceMode.patient;
    final header = inModule
        ? context.lang.setupConfigurationProgress(
            state.moduleIndex + 1,
            controller.modules.length,
          )
        : context.lang.setupTitle;
    return PopScope(
      canPop: allowExit || (state.step == 0 && !widget.saving),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !widget.saving) back();
      },
      child: Scaffold(
        appBar: AppBar(
          actions: [
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
                  onPressed: widget.saving ? null : back,
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
                    context.lang.setupStepFeatures,
                    context.lang.setupStepData,
                    context.lang.setupStepAccess,
                    state.step >= 4
                        ? context.lang.moduleName(controller.module)
                        : context.lang.setupStepConfiguration,
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
                      if (state.step == 0) ...[
                        SetupNotice(text: context.lang.setupDemoNotice),
                        const SizedBox(height: 16),
                      ],
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
          saving: widget.saving,
          onNext: () => next(context),
          onPreviousFeature: inModule && state.moduleIndex > 0 ? back : null,
          onSkip: inModule && controller.module != SetupModule.lowTreatment
              ? () => skip(context)
              : null,
          label: state.step == 5
              ? (savePatient
                    ? context.lang.setupPatientSave
                    : context.lang.setupFinishPreview)
              : context.lang.setupNext,
        ),
      ),
    );
  }
}
