import '../config/data_source_config.dart';
import 'data_receiver_controller.dart';
import 'data_receiver_source.dart';

class DataReceiverActivationController {
  DataReceiverActivationController({
    required DataReceiverController xdripReceiverController,
    required DataReceiverController aapsReceiverController,
  }) : _receivers = [
         DataReceiverRegistration(
           source: DataReceiverSource.xdripGlucose,
           controller: xdripReceiverController,
         ),
         DataReceiverRegistration(
           source: DataReceiverSource.aaps,
           controller: aapsReceiverController,
         ),
       ];

  final List<DataReceiverRegistration> _receivers;

  Future<void> enableConfiguredReceivers(DataSourceConfig config) async {
    for (final receiver in _receivers) {
      if (receiver.source.isActive(config)) {
        await receiver.controller.setEnabled();
      }
    }
  }

  Future<void> applyConfigChange({
    required DataSourceConfig previous,
    required DataSourceConfig next,
  }) async {
    for (final receiver in _receivers) {
      await _applyReceiverChange(receiver, previous, next);
    }
  }

  Future<void> _applyReceiverChange(
    DataReceiverRegistration receiver,
    DataSourceConfig previous,
    DataSourceConfig next,
  ) async {
    final wasActive = receiver.source.isActive(previous);
    final isActive = receiver.source.isActive(next);

    if (wasActive == isActive) return;

    if (isActive) {
      await receiver.controller.setEnabled();
    } else {
      await receiver.controller.setDisabled();
    }
  }
}

class DataReceiverRegistration {
  const DataReceiverRegistration({
    required this.source,
    required this.controller,
  });

  final DataReceiverSource source;
  final DataReceiverController controller;
}
