enum CgmSensorType {
  dexcomG7('Dexcom G7', 'Dexcom', 'G7'),
  dexcomG6('Dexcom G6', 'Dexcom', 'G6'),
  dexcomOne('Dexcom ONE', 'Dexcom', 'ONE'),
  dexcom('Dexcom', 'Dexcom', 'Dexcom'),
  libre3('FreeStyle Libre 3', 'Abbott', 'Libre 3'),
  libre2('FreeStyle Libre 2', 'Abbott', 'Libre 2'),
  libre('FreeStyle Libre', 'Abbott', 'Libre'),
  guardian('Guardian', 'Medtronic', 'Guardian'),
  eversense('Eversense', 'Senseonics', 'Eversense'),
  genericCgm('Sensor CGM', '', 'Sensor');

  const CgmSensorType(this.displayName, this.brand, this.shortName);
  final String displayName;
  final String brand;
  final String shortName;
}
