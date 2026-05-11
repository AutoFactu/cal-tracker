import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

abstract class GoogleSignInService {
  Future<String?> signIn();
  Future<void> signOut();
}

class GoogleSignInServiceImpl implements GoogleSignInService {
  static const _serverClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const _androidClientId =
      String.fromEnvironment('GOOGLE_ANDROID_CLIENT_ID');

  Future<void>? _initialization;

  @override
  Future<String?> signIn() async {
    await _ensureInitialized();
    try {
      return _authenticate();
    } on GoogleSignInException catch (error) {
      debugPrint(
          'Google sign-in failed: ${error.code} ${error.description ?? ''}');
      return null;
    } on PlatformException catch (error) {
      debugPrint('Google sign-in platform error: ${error.code}');
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    await _ensureInitialized();
    await GoogleSignIn.instance.signOut();
  }

  Future<void> _ensureInitialized() {
    return _initialization ??= GoogleSignIn.instance.initialize(
      clientId: _emptyToNull(_androidClientId),
      serverClientId: _emptyToNull(_serverClientId),
    );
  }

  Future<String?> _authenticate() async {
    GoogleSignInAccount account;
    try {
      account = await GoogleSignIn.instance.authenticate();
    } catch (_) {
      try {
        await GoogleSignIn.instance.disconnect();
      } catch (_) {}
      account = await GoogleSignIn.instance.authenticate();
    }
    return account.authentication.idToken;
  }

  static String? _emptyToNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
