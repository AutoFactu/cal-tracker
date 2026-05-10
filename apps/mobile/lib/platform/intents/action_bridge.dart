import '../../generated/api/cal_tracker_api.dart';

class PlatformActionBridge {
  const PlatformActionBridge({required CalTrackerApiClient apiClient})
      : _apiClient = apiClient;

  final CalTrackerApiClient _apiClient;

  Future<Map<String, Object?>> getDailySummary() {
    return _apiClient.executeAction('get_daily_summary', {});
  }

  Future<Map<String, Object?>> proposeMealLog(String text) {
    return _apiClient.executeAction('propose_meal_log', {'text': text});
  }
}
