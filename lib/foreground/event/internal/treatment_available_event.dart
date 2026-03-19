import '../../../core/domain/model/treatment_base.dart';
import '../model/foreground_event.dart';

class TreatmentAvailableEvent<T extends Treatment> extends ForegroundEvent {
  final T data;

  TreatmentAvailableEvent(this.data);
}