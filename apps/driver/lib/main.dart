import 'package:flutter/material.dart';
import 'package:rryd_core/rryd_core.dart';

import 'driver_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseBootstrap.initialize();
  await RrydNotificationService.initialize();
  final settings = await RrydAppSettings.load(appKey: 'driver');

  runApp(DriverApp(settings: settings));
}
