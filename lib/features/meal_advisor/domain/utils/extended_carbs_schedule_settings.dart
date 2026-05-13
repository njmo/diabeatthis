enum ExtendedCarbsDeliveryMode { extendedCarbs, extraBolus }

class ExtendedCarbsScheduleSettings {
  final ExtendedCarbsDeliveryMode deliveryMode;
  final int delayMinutes;
  final int durationMinutes;

  const ExtendedCarbsScheduleSettings({
    this.deliveryMode = ExtendedCarbsDeliveryMode.extendedCarbs,
    required this.delayMinutes,
    required this.durationMinutes,
  });

  const ExtendedCarbsScheduleSettings.defaults()
    : deliveryMode = ExtendedCarbsDeliveryMode.extendedCarbs,
      delayMinutes = 45,
      durationMinutes = 120;

  ExtendedCarbsScheduleSettings copyWith({
    ExtendedCarbsDeliveryMode? deliveryMode,
    int? delayMinutes,
    int? durationMinutes,
  }) {
    return ExtendedCarbsScheduleSettings(
      deliveryMode: deliveryMode ?? this.deliveryMode,
      delayMinutes: delayMinutes ?? this.delayMinutes,
      durationMinutes: durationMinutes ?? this.durationMinutes,
    );
  }
}
