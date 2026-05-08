import 'action_bridge.dart';

class IosAppIntentsAdapter {
  const IosAppIntentsAdapter({required PlatformActionBridge bridge, this.enabled = false}) : _bridge = bridge;

  final PlatformActionBridge _bridge;
  final bool enabled;

  Future<Map<String, Object?>> getDailySummary() {
    if (!enabled) return Future.value({'authenticationRequired': false, 'enabled': false});
    return _bridge.getDailySummary();
  }

  Future<Map<String, Object?>> proposeMealLog(String text) {
    if (!enabled) return Future.value({'authenticationRequired': false, 'enabled': false});
    return _bridge.proposeMealLog(text);
  }
}
