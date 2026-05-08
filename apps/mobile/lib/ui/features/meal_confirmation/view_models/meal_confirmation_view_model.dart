import 'package:flutter/foundation.dart';

class MealConfirmationViewModel extends ChangeNotifier {
  bool _isEditing = false;

  bool get isEditing => _isEditing;

  void setEditing(bool value) {
    _isEditing = value;
    notifyListeners();
  }
}
