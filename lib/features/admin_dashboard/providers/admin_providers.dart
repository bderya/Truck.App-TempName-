import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../models/models.dart';

final _supabase = Supabase.instance.client;

final adminDriversProvider = FutureProvider<List<User>>((ref) async {
  final res = await _supabase.from('users').select().eq('user_type', 'driver').order('id');
  return (res as List).map((e) => User.fromJson(e as Map<String, dynamic>)).toList();
});

final adminActiveTrucksProvider = FutureProvider<List<TowTruck>>((ref) async {
  final res = await _supabase.from('tow_trucks').select().eq('is_available', true);
  return (res as List).map((e) => TowTruck.fromJson(e as Map<String, dynamic>)).toList();
});

final adminBookingsProvider = FutureProvider<List<Booking>>((ref) async {
  final res = await _supabase.from('bookings').select().order('created_at', ascending: false);
  return (res as List).map((e) => Booking.fromJson(e as Map<String, dynamic>)).toList();
});

Future<void> adminSetUserVerified(int userId, bool verified) async {
  await _supabase.rpc('set_user_verified', params: {
    'p_user_id': userId,
    'p_verified': verified,
  });
}

Future<void> adminApproveUser(int userId, String status) async {
  await _supabase.rpc('approve_user', params: {
    'p_user_id': userId,
    'p_status': status,
  });
}
