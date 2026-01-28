import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  // Analytics supports Android/iOS/Web/macOS. We'll no-op on Windows/Linux.
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

  /// Accept nullable values, but FirebaseAnalytics requires non-null values.
  Future<void> logEvent(
    String name, {
    Map<String, Object?>? parameters,
  }) async {
    if (!supported || _analytics == null) return;

    // Convert Map<String, Object?> -> Map<String, Object> by dropping nulls
    Map<String, Object>? cleaned;
    if (parameters != null) {
      cleaned = <String, Object>{};
      parameters.forEach((key, value) {
        if (value != null) cleaned![key] = value;
      });
    }

    try {
      await _analytics!.logEvent(name: name, parameters: cleaned);
    } catch (_) {
      // ignore
    }
  }
}
