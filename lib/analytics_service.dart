import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // Firebase Analytics supports Android/iOS/Web/macOS.
  // We'll no-op on Windows so your desktop build stays fine.
  static bool get supported =>
      kIsWeb || Platform.isAndroid || Platform.isIOS || Platform.isMacOS;

  FirebaseAnalytics? _analytics;

  Future<void> init() async {
    if (!supported) return;
    try {
      _analytics = FirebaseAnalytics.instance;
    } catch (_) {
      _analytics = null;
    }
  }

  Future<void> logEvent(String name, {Map<String, Object?>? parameters}) async {
    if (!supported || _analytics == null) return;
    try {
      await _analytics!.logEvent(name: name, parameters: parameters);
    } catch (_) {
      // ignore
    }
  }
}
