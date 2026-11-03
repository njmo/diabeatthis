class NightscoutLowTreatmentSettings {
  const NightscoutLowTreatmentSettings({
    this.enabled = false,
    this.url = '',
    this.token = '',
    this.revision = '',
  });
  final bool enabled;
  final String url;
  final String token;
  final String revision;
}
