import 'package:flutter/material.dart';
import 'package:rryd_core/rryd_core.dart';

import 'passenger_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SupabaseBootstrap.initialize();
  final settings = await RrydAppSettings.load(appKey: 'passenger');

  runApp(PassengerApp(settings: settings));
}
