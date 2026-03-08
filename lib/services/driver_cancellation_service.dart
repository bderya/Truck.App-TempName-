import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of driver cancelling an accepted booking.
class DriverCancelResult {
  const DriverCancelResult({
    required this.ok,
    this.penaltyApplied = false,
    this.penaltyAmount = 0,
    this.suspended = false,
    this.error,
  });

  final bool ok;
  final bool penaltyApplied;
  final double penaltyAmount;
  final bool suspended;
  final String? error;
}

/// Handles driver cancellation: RPC, penalty, violation, suspension, client recovery.
class DriverCancellationService {
  DriverCancellationService({required this.client});

  final SupabaseClient client;

  /// Driver cancels an accepted/on_the_way/picked_up booking.
  /// If >50% through ETA: 250 TL penalty, violation logged, quality -0.3.
  /// 3 cancellations in 7 days → 48h suspension. Booking re-opens as priority rematch.
  Future<DriverCancelResult> cancelBookingByDriver({
    required int bookingId,
    required int driverId,
  }) async {
    try {
      final res = await client.rpc('cancel_booking_by_driver', params: {
        'p_booking_id': bookingId,
        'p_driver_id': driverId,
      });
      if (res == null) return const DriverCancelResult(ok: false, error: 'Invalid response');
      final map = res as Map<String, dynamic>;
      final ok = map['ok'] as bool? ?? false;
      if (!ok) {
        return DriverCancelResult(
          ok: false,
          error: map['error'] as String? ?? 'İşlem başarısız',
        );
      }
      return DriverCancelResult(
        ok: true,
        penaltyApplied: map['penalty_applied'] as bool? ?? false,
        penaltyAmount: (map['penalty_amount'] as num?)?.toDouble() ?? 0,
        suspended: map['suspended'] as bool? ?? false,
      );
    } catch (e) {
      return DriverCancelResult(ok: false, error: e.toString());
    }
  }
}
