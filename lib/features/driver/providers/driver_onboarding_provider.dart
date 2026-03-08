import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/models.dart';
import 'driver_booking_provider.dart';
import '../../auth/providers/auth_state_provider.dart';

/// Tow truck for the currently logged-in app user (by auth phone -> user id).
/// Used to decide: has driver completed onboarding? (has truck = yes)
final currentAuthUserTowTruckProvider = FutureProvider<TowTruck?>((ref) async {
  final user = await ref.watch(currentAppUserProvider.future);
  if (user == null) return null;
  try {
    final res = await Supabase.instance.client
        .from('tow_trucks')
        .select()
        .eq('driver_id', user.id)
        .maybeSingle();
    if (res == null) return null;
    return TowTruck.fromJson(res as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
});
