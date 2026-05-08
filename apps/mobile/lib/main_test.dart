import 'package:flutter/material.dart';
// ignore: depend_on_referenced_packages
import 'package:flutter_driver/driver_extension.dart';

import 'app/app.dart';

void main() {
  enableFlutterDriverExtension();
  runApp(const CalTrackerBootstrap());
}
