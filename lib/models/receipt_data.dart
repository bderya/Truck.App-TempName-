import 'booking.dart';

/// Aggregated data for the job summary & receipt (booking + driver + duration).
class ReceiptData {
  const ReceiptData({
    required this.booking,
    required this.driverName,
    required this.plateNumber,
    this.duration,
    this.distanceKm,
  });

  final Booking booking;
  final String driverName;
  final String plateNumber;
  final Duration? duration;
  final double? distanceKm;

  String get formattedDuration {
    if (duration == null) return '—';
    final d = duration!;
    if (d.inHours > 0) return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    return '${d.inMinutes}m';
  }

  String get formattedDistance =>
      distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : '—';
}
