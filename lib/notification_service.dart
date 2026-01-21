import 'dart:io';

/// Desktop-safe placeholder notification service.
/// On Windows it does nothing (so your app keeps building).
/// Later, when you run Android/iOS, we can upgrade this to real notifications.
class NotificationService {
  NotificationService._();
  static final instance = NotificationService._();

  bool get supported => Platform.isAndroid || Platform.isIOS;

  Future<void> init() async {
    // No-op for now on Windows desktop.
  }

  Future<void> showTestIn5Seconds() async {
    // No-op for now on Windows desktop.
  }

  Future<void> cancelAll() async {
    // No-op for now on Windows desktop.
  }
}
