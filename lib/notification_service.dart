import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _ready = false;

  bool get supported => !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'parkpal_reminders',
    'ParkPal Reminders',
    description: 'Notifications for ParkPal reminders and actions.',
    importance: Importance.high,
  );

  Future<void> init() async {
    if (!supported || _ready) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const settings =
        InitializationSettings(android: androidInit, iOS: iosInit);

    await _plugin.initialize(settings);

    if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

      // Create channel (Android 8+)
      await androidImpl?.createNotificationChannel(_channel);

      // Request runtime permission (Android 13+)
      await androidImpl?.requestNotificationsPermission();
    }

    if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      await iosImpl?.requestPermissions(alert: true, badge: true, sound: true);
    }

    _ready = true;
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        'parkpal_reminders',
        'ParkPal Reminders',
        channelDescription: 'Notifications for ParkPal reminders and actions.',
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
  }

  /// Simple test: waits 5 seconds then shows a notification.
  /// (No scheduling API, so no exact-alarm headaches.)
  Future<void> showTestIn5Seconds() async {
    if (!_ready) return;

    await Future.delayed(const Duration(seconds: 5));

    await _plugin.show(
      1001,
      'ParkPal',
      'Test notification: ParkPal reminders are working ✅',
      _details(),
    );
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
