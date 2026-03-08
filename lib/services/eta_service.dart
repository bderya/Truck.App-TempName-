import 'package:latlong2/latlong.dart';

/// Recalculates ETA when driver coordinates change.
/// Uses straight-line distance and an assumed average speed (e.g. city traffic).
class EtaService {
  EtaService({this.averageSpeedKmh = 25});

  /// Assumed average speed in km/h (e.g. 25 for city).
  final double averageSpeedKmh;

  static const _distance = Distance();

  /// Returns estimated time of arrival from [driverLat], [driverLng] to [destLat], [destLng].
  /// Recalculate whenever driver position updates.
  Duration calculateEta({
    required double driverLat,
    required double driverLng,
    required double destLat,
    required double destLng,
  }) {
    final meters = _distance(
      LatLng(driverLat, driverLng),
      LatLng(destLat, destLng),
    );
    final km = (meters as num).toDouble() / 1000;
    final hours = km / averageSpeedKmh;
    return Duration(minutes: (hours * 60).round().clamp(0, 24 * 60));
  }

  /// Returns distance in km (for display).
  double distanceKm(double driverLat, double driverLng, double destLat, double destLng) {
    final meters = _distance(
      LatLng(driverLat, driverLng),
      LatLng(destLat, destLng),
    );
    return (meters as num).toDouble() / 1000;
  }
}
