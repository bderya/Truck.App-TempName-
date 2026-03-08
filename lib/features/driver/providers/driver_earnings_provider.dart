import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../models/models.dart';
import 'driver_booking_provider.dart';

/// Filter for earnings: by day, week, or month.
enum EarningsFilter { day, week, month }

/// Fetches all completed bookings for the current driver from Supabase.
Future<List<Booking>> _fetchCompletedBookings(int driverId) async {
  final res = await Supabase.instance.client
      .from('bookings')
      .select()
      .eq('driver_id', driverId)
      .eq('status', 'completed')
      .order('ended_at', ascending: false);

  if (res == null || res is! List) return [];
  return (res as List)
      .map((e) => Booking.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Net payout for a booking. Uses stored driver_net_amount when set (dynamic commission), else fallback.
double netPayout(Booking b) {
  if (b.driverNetAmount != null && b.driverNetAmount! > 0) {
    return b.driverNetAmount!;
  }
  final price = b.price ?? 0;
  return price * (1 - AppConstants.platformCommissionRate);
}

/// Gross (total price) for a booking.
double grossPayout(Booking b) {
  return b.price ?? 0;
}

final driverCompletedBookingsProvider = FutureProvider.family<List<Booking>, int>((ref, driverId) async {
  return _fetchCompletedBookings(driverId);
});

/// Current earnings filter (day / week / month).
final earningsFilterProvider = StateProvider<EarningsFilter>((ref) => EarningsFilter.week);

/// Completed bookings for the current driver, filtered by selected period.
final driverEarningsBookingsProvider = Provider<AsyncValue<List<Booking>>>((ref) {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return const AsyncValue.data([]);
  final filter = ref.watch(earningsFilterProvider);
  final asyncBookings = ref.watch(driverCompletedBookingsProvider(driverId));

  return asyncBookings.whenData((all) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    bool inRange(Booking b) {
      final t = b.endedAt ?? b.createdAt ?? now;
      final d = t.isUtc ? t.toLocal() : t;
      final dateOnly = DateTime(d.year, d.month, d.day);

      switch (filter) {
        case EarningsFilter.day:
          return dateOnly == todayStart;
        case EarningsFilter.week:
          final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
          return !dateOnly.isBefore(weekStart) && dateOnly.isBefore(weekStart.add(const Duration(days: 7)));
        case EarningsFilter.month:
          return d.year == now.year && d.month == now.month;
      }
    }

    return all.where(inRange).toList();
  });
});

/// Today's earnings (net) from completed bookings.
final todayEarningsProvider = Provider<AsyncValue<double>>((ref) {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return const AsyncValue.data(0);
  final asyncBookings = ref.watch(driverCompletedBookingsProvider(driverId));
  return asyncBookings.whenData((list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    return list
        .where((b) {
          final t = b.endedAt ?? b.createdAt;
          if (t == null) return false;
          final d = t.isUtc ? t.toLocal() : t;
          return DateTime(d.year, d.month, d.day) == todayStart;
        })
        .fold<double>(0, (sum, b) => sum + netPayout(b));
  });
});

/// This week's total (net) from completed bookings.
final weekEarningsProvider = Provider<AsyncValue<double>>((ref) {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return const AsyncValue.data(0);
  final asyncBookings = ref.watch(driverCompletedBookingsProvider(driverId));
  return asyncBookings.whenData((list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = todayStart.subtract(Duration(days: todayStart.weekday - 1));
    return list
        .where((b) {
          final t = b.endedAt ?? b.createdAt;
          if (t == null) return false;
          final d = t.isUtc ? t.toLocal() : t;
          final dateOnly = DateTime(d.year, d.month, d.day);
          return !dateOnly.isBefore(weekStart) && dateOnly.isBefore(weekStart.add(const Duration(days: 7)));
        })
        .fold<double>(0, (sum, b) => sum + netPayout(b));
  });
});

/// Last 7 days daily net earnings for the chart (index 0 = oldest day).
final weeklyTrendProvider = Provider<AsyncValue<List<double>>>((ref) {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return const AsyncValue.data(List.filled(7, 0.0));
  final asyncBookings = ref.watch(driverCompletedBookingsProvider(driverId));
  return asyncBookings.whenData((list) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final out = List<double>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final dayStart = todayStart.subtract(Duration(days: 6 - i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      out[i] = list
          .where((b) {
            final t = b.endedAt ?? b.createdAt;
            if (t == null) return false;
            final d = t.isUtc ? t.toLocal() : t;
            return d.isAfter(dayStart.subtract(const Duration(seconds: 1))) && d.isBefore(dayEnd);
          })
          .fold<double>(0, (sum, b) => sum + netPayout(b));
    }
    return out;
  });
});
