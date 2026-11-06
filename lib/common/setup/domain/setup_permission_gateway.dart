import 'setup_feature.dart';

abstract interface class SetupPermissionGateway {
  Future<bool> check(SetupRequirement requirement);
  Future<bool> request(SetupRequirement requirement);
}
