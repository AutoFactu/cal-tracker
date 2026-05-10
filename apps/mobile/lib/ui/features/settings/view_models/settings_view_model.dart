import 'package:flutter/foundation.dart';

import '../../../../data/repositories/auth_repository.dart';
import '../../../../domain/models/auth_models.dart';

class SettingsViewModel extends ChangeNotifier {
  SettingsViewModel({required AuthRepository authRepository})
      : _authRepository = authRepository;

  final AuthRepository _authRepository;
  bool _isLoading = false;
  String? _error;

  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<AuthUser?> setTrustedMode(bool enabled) async {
    _isLoading = true;
    notifyListeners();
    try {
      final user = await _authRepository.updateTrustedMode(enabled);
      _error = null;
      return user;
    } catch (error) {
      _error = error.toString();
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
