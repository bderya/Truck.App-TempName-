import 'package:supabase_flutter/supabase_flutter.dart';

/// Result of dynamic commission calculation (tier + surge).
class CommissionSplit {
  const CommissionSplit({
    required this.driverNetAmount,
    required this.platformAmount,
    required this.commissionPercent,
    required this.platformPercent,
    required this.driverPercent,
    this.isSurge = false,
  });

  final double driverNetAmount;
  final double platformAmount;
  final double commissionPercent;
  final double platformPercent;
  final double driverPercent;
  final bool isSurge;

  static CommissionSplit? fromRpcResult(Map<String, dynamic>? res) {
    if (res == null || res['ok'] != true) return null;
    final net = (res['net_amount'] as num?)?.toDouble();
    final platform = (res['platform_amount'] as num?)?.toDouble();
    final pct = (res['commission_percent'] as num?)?.toDouble();
    final platformPct = (res['platform_percent'] as num?)?.toDouble();
    final driverPct = (res['driver_percent'] as num?)?.toDouble();
    if (net == null || platform == null) return null;
    return CommissionSplit(
      driverNetAmount: net,
      platformAmount: platform,
      commissionPercent: pct ?? 0.25 * 100,
      platformPercent: platformPct ?? 0.25,
      driverPercent: driverPct ?? 0.75,
      isSurge: res['is_surge'] as bool? ?? false,
    );
  }
}

/// Calls calculate_net_earnings RPC for dynamic commission (tiers + surge).
/// Use the returned platform_percent and driver_percent in capture/split API.
class CommissionService {
  CommissionService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Returns split for a booking completion. Pass booking price, driver_id, and booking_id.
  Future<CommissionSplit?> calculateNetEarnings({
    required double totalPrice,
    required int driverId,
    int? bookingId,
  }) async {
    try {
      final res = await _client.rpc(
        'calculate_net_earnings',
        params: {
          'p_total_price': totalPrice,
          'p_driver_id': driverId,
          'p_booking_id': bookingId,
        },
      ) as Map<String, dynamic>?;
      return CommissionSplit.fromRpcResult(res);
    } catch (_) {
      return null;
    }
  }
}
