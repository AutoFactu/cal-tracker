import 'dart:convert';

import 'package:cal_tracker_mobile/data/repositories/auth_repository.dart';
import 'package:cal_tracker_mobile/data/services/api_config.dart';
import 'package:cal_tracker_mobile/data/services/google_sign_in_service.dart';
import 'package:cal_tracker_mobile/data/services/secure_token_storage.dart';
import 'package:cal_tracker_mobile/generated/api/cal_tracker_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  test('loginWithGoogle exchanges an ID token and stores API tokens',
      () async {
    final tokenStorage = _MemoryTokenStorage();
    final apiClient = CalTrackerApiClient(
      config: const ApiConfig(baseUrl: 'http://localhost'),
      tokenStorage: tokenStorage,
      httpClient: MockClient((request) async {
        expect(request.url.path, '/v1/auth/google/login');
        expect(jsonDecode(request.body), {'idToken': 'google-id-token'});
        return http.Response(
          jsonEncode({
            'accessToken': 'access-token',
            'refreshToken': 'refresh-token',
            'expiresAt': DateTime.now().toIso8601String(),
            'user': {
              'id': 'user-id',
              'email': 'google@example.com',
              'displayName': 'Google User',
              'trustedModeEnabled': false,
              'createdAt': DateTime.now().toIso8601String(),
            },
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );
    final repository = AuthRepository(
      apiClient: apiClient,
      tokenStorage: tokenStorage,
      googleSignInService: _FakeGoogleSignInService('google-id-token'),
    );

    final session = await repository.loginWithGoogle();

    expect(session?.user.email, 'google@example.com');
    expect(await tokenStorage.read(), isNotNull);
    expect((await tokenStorage.read())?.accessToken, 'access-token');
  });
}

class _FakeGoogleSignInService implements GoogleSignInService {
  _FakeGoogleSignInService(this.idToken);

  final String? idToken;

  @override
  Future<String?> signIn() async => idToken;

  @override
  Future<void> signOut() async {}
}

class _MemoryTokenStorage implements TokenStorage {
  StoredTokens? _tokens;

  @override
  Future<void> clear() async {
    _tokens = null;
  }

  @override
  Future<StoredTokens?> read() async => _tokens;

  @override
  Future<void> write(StoredTokens tokens) async {
    _tokens = tokens;
  }
}
