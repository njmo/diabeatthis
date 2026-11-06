enum SetupDeviceMode { patient, caregiver }

enum SetupFeatureId {
  mealMonitor,
  activityMonitor,
  mealPhoto,
  aiAssistance,
  familyChat,
  childOverview,
}

enum SetupRequirement {
  notifications,
  backgroundExecution,
  camera,
  googleAccount,
  familyPairing,
  internet,
  aiConfiguration,
  dataSource,
}

enum SetupModule { family, ai, nightscout }

class SetupPersonConfiguration {
  const SetupPersonConfiguration({required this.mode});
  final SetupDeviceMode mode;
}

class SetupFeature {
  const SetupFeature({
    required this.id,
    required this.modes,
    required this.requirements,
  });
  final SetupFeatureId id;
  final Set<SetupDeviceMode> modes;
  final Set<SetupRequirement> requirements;
}
