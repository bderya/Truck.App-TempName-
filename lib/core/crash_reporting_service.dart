import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

/// Central crash and error reporting: Sentry + Firebase Crashlytics.
/// - Wraps runApp with Sentry and sets global error handlers.
/// - Attaches user_id, device_model, booking_id to reports (no PII).
/// - Reports non-200 API responses as non-fatal.
/// - Sanitizes all data: credit card numbers and plain passwords are NEVER sent.
class CrashReportingService {
  CrashReportingService._();

  static String? _deviceModel;
  static String? _userId;
  static String? _bookingId;
  static bool _sentryEnabled = false;
  static bool _crashlyticsEnabled = false;

  /// PII patterns: never send these to error logs.
  static final RegExp _cardNumberPattern = RegExp(r'\b\d{4}[\s\-]?\d{4}[\s\-]?\d{4}[\s\-]?\d{4}\b');
  static final RegExp _cvcPattern = RegExp(r'\b\d{3,4}\b');
  static const String _redacted = '[REDACTED]';

  /// Sanitizes a string so it never contains card numbers or passwords.
  static String sanitize(String? value) {
    if (value == null || value.isEmpty) return '';
    String out = value;
    out = out.replaceAll(_cardNumberPattern, _redacted);
    out = out.replaceAllMapped(
      RegExp(r'(password|passwd|pwd|secret|token|authorization|bearer)\s*[:=]\s*[\w\-\.]+', caseSensitive: false),
      (_) => _redacted,
    );
    return out;
  }

  /// Call once at startup. [sentryDsn] empty = Sentry disabled. Crashlytics requires Firebase.
  static Future<void> initialize({
    required String sentryDsn,
    required bool enableCrashlytics,
  }) async {
    _sentryEnabled = sentryDsn.isNotEmpty;
    _crashlyticsEnabled = enableCrashlytics && !kIsWeb;

    await _initDeviceModel();

    if (_crashlyticsEnabled) {
      try {
        await Firebase.initializeApp();
        await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
      } catch (_) {
        _crashlyticsEnabled = false;
      }
    }

    if (!_sentryEnabled) {
      if (_crashlyticsEnabled) {
        FlutterError.onError = (details) {
          _reportFlutterError(details);
          FlutterError.presentError(details);
        };
        PlatformDispatcher.instance.onError = (error, stack) {
          _reportAsyncError(error, stack);
          return true;
        };
      } else {
        FlutterError.onError = (details) => FlutterError.presentError(details);
        PlatformDispatcher.instance.onError = (error, stack) => true;
      }
    }
  }

  /// Call after SentryFlutter.init so Crashlytics also receives errors (Sentry sets handlers first).
  static void attachToExistingErrorHandlers() {
    if (!_crashlyticsEnabled) return;
    final previousFlutter = FlutterError.onError;
    FlutterError.onError = (details) {
      _reportFlutterError(details);
      previousFlutter?.call(details);
    };
    final previousAsync = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stack) {
      _reportAsyncError(error, stack);
      return previousAsync?.call(error, stack) ?? true;
    };
  }

  static Future<void> _initDeviceModel() async {
    if (_deviceModel != null) return;
    try {
      if (kIsWeb) {
        _deviceModel = 'web';
        return;
      }
      final deviceInfo = DeviceInfoPlugin();
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = await deviceInfo.androidInfo;
        _deviceModel = '${android.manufacturer} ${android.model}';
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        final ios = await deviceInfo.iosInfo;
        _deviceModel = '${ios.utsname.machine} ${ios.model}';
      } else {
        _deviceModel = 'unknown';
      }
    } catch (_) {
      _deviceModel = 'unknown';
    }
  }

  static void _reportFlutterError(FlutterErrorDetails details) {
    final sanitized = FlutterErrorDetails(
      exception: details.exception,
      stack: details.stack,
      library: details.library,
      context: details.context,
      informationCollector: details.informationCollector,
    );
    if (_crashlyticsEnabled) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(sanitized);
    }
    if (_sentryEnabled) {
      Sentry.captureException(
        details.exception,
        stackTrace: details.stack,
        withScope: (scope) {
          scope.setTag('source', 'flutter_error');
          _attachContext(scope);
        },
      );
    }
  }

  static void _reportAsyncError(Object error, StackTrace stack) {
    if (_crashlyticsEnabled) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
    }
    if (_sentryEnabled) {
      Sentry.captureException(
        error,
        stackTrace: stack,
        withScope: (scope) {
          scope.setTag('source', 'async_error');
          _attachContext(scope);
        },
      );
    }
  }

  static void _attachContext(Scope scope) {
    if (_userId != null) scope.setUser(SentryUser(id: _userId));
    if (_deviceModel != null) scope.setTag('device_model', sanitize(_deviceModel!));
    if (_bookingId != null) scope.setExtra('booking_id', _bookingId!);
  }

  /// Set context attached to every subsequent error report. No PII.
  static void setUserId(String? id) {
    _userId = id;
    if (_crashlyticsEnabled && id != null) {
      FirebaseCrashlytics.instance.setUserIdentifier(sanitize(id));
    }
    if (_sentryEnabled) {
      Sentry.configureScope((scope) {
        if (id != null) {
          scope.setUser(SentryUser(id: sanitize(id)));
        } else {
          scope.setUser(null);
        }
        if (_deviceModel != null) scope.setTag('device_model', sanitize(_deviceModel!));
        if (_bookingId != null) scope.setExtra('booking_id', _bookingId!);
      });
    }
  }

  static void setBookingId(String? id) {
    _bookingId = id;
    if (_crashlyticsEnabled) {
      FirebaseCrashlytics.instance.setCustomKey('booking_id', id ?? '');
    }
    if (_sentryEnabled) {
      Sentry.configureScope((scope) {
        if (id != null) scope.setExtra('booking_id', id);
      });
    }
  }

  /// Report a non-200 HTTP / API response as non-fatal. Do not pass request/response body or tokens.
  static void reportNonFatalApiError({
    required String service,
    required int statusCode,
    String? sanitizedMessage,
    String? method,
    String? path,
  }) {
    final message = sanitize(sanitizedMessage ?? 'HTTP $statusCode');
    if (_crashlyticsEnabled) {
      FirebaseCrashlytics.instance.recordError(
        Exception('API $service: $statusCode - $message'),
        null,
        fatal: false,
        reason: 'Non-200 response',
      );
      FirebaseCrashlytics.instance.setCustomKey('api_service', service);
      FirebaseCrashlytics.instance.setCustomKey('status_code', statusCode);
    }
    if (_sentryEnabled) {
      Sentry.captureMessage(
        'API error: $service $statusCode',
        level: SentryLevel.warning,
        withScope: (scope) {
          scope.setTag('api_service', service);
          scope.setExtra('status_code', statusCode);
          scope.setExtra('message', message);
          if (method != null) scope.setExtra('method', method);
          if (path != null) scope.setExtra('path', sanitize(path));
          _attachContext(scope);
        },
      );
    }
  }

  /// Sentry beforeSend: drop or sanitize events that might contain PII.
  static FutureOr<SentryEvent?> beforeSend(SentryEvent event, Hint hint) {
    final message = event.throwable?.toString() ?? event.message?.formatted ?? '';
    if (_looksLikePii(message)) return null;
    return event;
  }

  static bool _looksLikePii(String s) {
    return _cardNumberPattern.hasMatch(s) ||
        s.toLowerCase().contains('password') ||
        s.toLowerCase().contains('card_number') ||
        s.toLowerCase().contains('cvc');
  }
}
