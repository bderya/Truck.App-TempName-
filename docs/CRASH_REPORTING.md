# Crash Reporting (Sentry + Firebase Crashlytics)

## Overview

- **Sentry**: Wraps `runApp()` and captures unhandled exceptions. Configure with `_sentryDsn` in `main.dart`.
- **Firebase Crashlytics**: Receives the same errors via global handlers. Enable with `_enableCrashlytics` and Firebase config.

## Initialization

1. **CrashReportingService.initialize()** runs first (in `main()`):
   - Loads **device_model** (Android/iOS) for context.
   - If Crashlytics enabled: `Firebase.initializeApp()` and enables collection.
   - If Sentry disabled: installs **FlutterError.onError** and **PlatformDispatcher.instance.onError** to report to Crashlytics only.

2. **Sentry** (when DSN is set):
   - **SentryFlutter.init()** wraps the app and installs its own error hooks.
   - **beforeSend** uses **CrashReportingService.beforeSend** to drop events that look like PII.
   - **CrashReportingService.attachToExistingErrorHandlers()** runs inside `appRunner` so Crashlytics also receives errors (wraps Sentry’s handlers).

## Global Error Handlers

- **FlutterError.onError**: All Flutter framework errors → reported to Sentry (via its integration) and to Crashlytics (via our wrapper).
- **PlatformDispatcher.instance.onError**: Asynchronous errors → both Sentry and Crashlytics (async reported as non-fatal in Crashlytics).

## Context (no PII)

- **user_id**: Set when the app user is resolved (`_FcmRegistration`), cleared on sign out.
- **device_model**: Set once at startup (e.g. "Samsung SM-G991B", "iPhone14,2").
- **booking_id**: Set when entering **DriverTrackingScreen**, cleared on dispose.

All context is attached to Sentry (user, tags, extras) and Crashlytics (user identifier, custom keys).

## API Interceptor

- **Supabase**: **SupabaseHttpClient** (in `lib/core/supabase_http_client.dart`) wraps every HTTP request. On status code &lt; 200 or ≥ 300 it calls **CrashReportingService.reportNonFatalApiError(service: 'supabase', statusCode, ...)**. No request/response body is logged.
- **Payment (Iyzico/Stripe RPC)**: Payment RPCs go through Supabase, so non-2xx are already reported as Supabase. In addition, **StripePaymentService** calls **reportNonFatalApiError(service: 'payment', ...)** when an RPC returns `ok != true` or when a catch block runs, with a **sanitized message only** (e.g. "Add card failed", "Authorization failed").

## Privacy (PII)

- **CrashReportingService.sanitize()** redacts:
  - Card number patterns (4×4 digits).
  - Strings like `password=...`, `token=...`, `authorization=...`.
- **beforeSend** (Sentry): If the event message/exception looks like PII (**CrashReportingService._looksLikePii**), the event is **dropped** (returns `null`).
- **Never** attach request/response bodies, raw card numbers, or plain passwords to reports. Only status codes, sanitized messages, and method/path (path sanitized) are sent.

## Configuration

- **main.dart**: `_sentryDsn` (empty = Sentry off), `_enableCrashlytics` (true = use Crashlytics when Firebase is configured).
- **Firebase**: Add `google-services.json` (Android) and run `flutterfire configure` if needed so Crashlytics can run.

## Files

| File | Role |
|------|------|
| `lib/core/crash_reporting_service.dart` | Init, handlers, context, sanitize, reportNonFatalApiError, beforeSend |
| `lib/core/supabase_http_client.dart` | HTTP client that reports non-2xx to crash reporting |
| `lib/main.dart` | Init order, runApp wrap, setUserId on auth, setBookingId in tracking |
| `lib/services/payment/stripe_payment_service.dart` | reportNonFatalApiError for payment RPC failures |
