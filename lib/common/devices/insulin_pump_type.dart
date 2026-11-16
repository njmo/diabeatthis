enum InsulinPumpType {
  ypsopump('YpsoPump', 'Ypsomed', 'Ypso'),
  omnipod('Omnipod', 'Insulet', 'Pod'),
  dana('Dana-i', 'SOOIL', 'Dana'),
  medtronic('MiniMed', 'Medtronic', 'MiniMed'),
  combo('Accu-Chek Combo', 'Roche', 'Combo'),
  genericPump('Pompa', '', 'Pompa');

  const InsulinPumpType(this.displayName, this.manufacturer, this.shortName);
  final String displayName;
  final String manufacturer;
  final String shortName;
}
