import 'package:drift/drift.dart' as d;

import '../../domain/model/portion.dart';
import '../entity/portion.dart';

extension PortionDataToDomain on PortionData {
  Portion toDomain() => Portion(
    id: id,
    name: name,
    unitHint: unitHint,
  );
}

extension PortionDataIterableToDomain on Iterable<PortionData> {
  List<Portion> toDomainList() => map((e) => e.toDomain()).toList();
}

extension DomainPortionToCompanion on Portion {
  PortionCompanion toCompanion() {
    return PortionCompanion(
      id: d.Value(id),
      name: d.Value(name),
      unitHint: d.Value(unitHint),
    );
  }
}
