import 'package:http/http.dart' as http;

import 'crash_reporting_service.dart';

/// HTTP client that reports non-2xx responses to Sentry/Crashlytics as non-fatal.
/// Never logs request/response body (PII-safe).
class SupabaseHttpClient extends http.BaseClient {
  SupabaseHttpClient({http.Client? inner}) : _inner = inner ?? http.Client();

  final http.Client _inner;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _inner.send(request);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      CrashReportingService.reportNonFatalApiError(
        service: 'supabase',
        statusCode: response.statusCode,
        sanitizedMessage: 'HTTP ${response.statusCode}',
        method: request.method,
        path: request.url.path.isEmpty ? request.url.toString() : request.url.path,
      );
    }
    return response;
  }
}
