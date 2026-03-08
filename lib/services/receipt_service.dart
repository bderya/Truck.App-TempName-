import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/providers.dart';
import '../models/models.dart';

/// Fetches full receipt data for a completed booking (booking + driver name + plate).
Future<ReceiptData?> fetchReceiptData(int bookingId) async {
  final client = Supabase.instance.client;
  final bookingRes = await client
      .from('bookings')
      .select()
      .eq('id', bookingId)
      .maybeSingle();
  if (bookingRes == null) return null;

  final booking = Booking.fromJson(bookingRes as Map<String, dynamic>);
  final driverId = booking.driverId;
  if (driverId == null) return null;

  String driverName = 'Driver';
  String plateNumber = '—';

  final userRes = await client.from('users').select('full_name').eq('id', driverId).maybeSingle();
  if (userRes != null) driverName = userRes['full_name'] as String? ?? driverName;

  final truckRes = await client
      .from('tow_trucks')
      .select('plate_number')
      .eq('driver_id', driverId)
      .maybeSingle();
  if (truckRes != null) plateNumber = truckRes['plate_number'] as String? ?? plateNumber;

  Duration? duration;
  if (booking.createdAt != null && booking.endedAt != null) {
    duration = booking.endedAt!.difference(booking.createdAt!);
  }

  double? distanceKm;
  if (booking.price != null && booking.price! > 0) {
    // Optional: derive approximate distance from price formula inverse for display only.
    distanceKm = null;
  }

  return ReceiptData(
    booking: booking,
    driverName: driverName,
    plateNumber: plateNumber,
    duration: duration,
    distanceKm: distanceKm,
  );
}

/// Requests the backend to send the receipt by email (link or attachment).
Future<bool> sendReceiptEmail({required int bookingId, required String toEmail}) async {
  try {
    final client = Supabase.instance.client;
    final res = await client.rpc('send_receipt_email', params: {
      'p_booking_id': bookingId,
      'p_to_email': toEmail,
    });
    final map = res as Map<String, dynamic>?;
    return map?['ok'] == true;
  } catch (_) {
    return false;
  }
}
