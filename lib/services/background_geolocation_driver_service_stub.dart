import 'package:supabase_flutter/supabase_flutter.dart';

/// Stub for web/desktop: no background geolocation plugin.
class BackgroundGeolocationDriverService {
  BackgroundGeolocationDriverService({SupabaseClient? supabase});

  Future<void> ensureConfigured() async {}
  Future<void> start(int towTruckId) async {}
  Future<void> stop() async {}
}
