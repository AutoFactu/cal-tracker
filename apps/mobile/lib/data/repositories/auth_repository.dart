import '../../domain/models/auth_models.dart';
import '../../generated/api/cal_tracker_api.dart';
import '../services/secure_token_storage.dart';

class AuthRepository {
  AuthRepository(
      {required CalTrackerApiClient apiClient,
      required TokenStorage tokenStorage})
      : _apiClient = apiClient,
        _tokenStorage = tokenStorage;

  final CalTrackerApiClient _apiClient;
  final TokenStorage _tokenStorage;

  Future<AuthSession> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    final json = await _apiClient.register(
        email: email, password: password, displayName: displayName);
    final session = AuthSession.fromJson(json);
    await _tokenStorage.write(StoredTokens(
        accessToken: session.accessToken, refreshToken: session.refreshToken));
    return session;
  }

  Future<AuthSession> login(
      {required String email, required String password}) async {
    final json = await _apiClient.login(email: email, password: password);
    final session = AuthSession.fromJson(json);
    await _tokenStorage.write(StoredTokens(
        accessToken: session.accessToken, refreshToken: session.refreshToken));
    return session;
  }

  Future<AuthUser?> restoreSession() async {
    final tokens = await _tokenStorage.read();
    if (tokens == null) return null;
    try {
      final user = AuthUser.fromJson(await _apiClient.getMe());
      return user;
    } on Object {
      await _tokenStorage.clear();
      return null;
    }
  }

  Future<AuthUser> updateTrustedMode(bool enabled) async {
    final json = await _apiClient.updateSettings(trustedModeEnabled: enabled);
    return AuthUser.fromJson(json['user'] as Map<String, Object?>);
  }

  Future<void> logout() => _tokenStorage.clear();
}
