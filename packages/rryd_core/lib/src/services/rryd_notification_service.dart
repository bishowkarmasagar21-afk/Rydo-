import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Local, foreground notification support for Rryd.
/// Remote push notifications require FCM/APNs configuration and a trusted
/// server-side sender; this class does not claim to replace remote push.
class RrydNotificationService {
  RrydNotificationService._();

  static final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> initialize() async {
    if (_initialized) return;

    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      ),
    );

    await _plugin.initialize(settings: settings);
    _initialized = true;
  }

  /// Ask for notification permission after the driver explicitly chooses
  /// "Go online", not at first app launch.
  static Future<bool> requestPermission() async {
    if (!_initialized) await initialize();

    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? false;
    }

    if (Platform.isIOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      return await ios?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }

    return true;
  }

  static Future<void> showRideRequest({
    required int rideId,
    required String pickup,
    required String destination,
    required String vehicleType,
  }) async {
    if (!_initialized) await initialize();

    const androidDetails = AndroidNotificationDetails(
      'rryd_ride_requests',
      'Ride requests',
      channelDescription: 'New passenger ride requests for online drivers.',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      category: AndroidNotificationCategory.call,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    await _plugin.show(
      id: rideId.abs() % 2147483647,
      title: 'New Rryd ride request',
      body: '${vehicleType.toUpperCase()} · $pickup → $destination',
      notificationDetails: const NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
      payload: rideId.toString(),
    );
  }
}
