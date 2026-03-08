import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/constants.dart';

/// Result of a price estimation: minimum and maximum range (avoids fixed-price legal issues).
class PriceEstimate {
  const PriceEstimate({
    required this.minimum,
    required this.maximum,
    required this.distanceKm,
    required this.isNightShift,
    this.breakdown,
  });

  final double minimum;
  final double maximum;
  final double distanceKm;
  final bool isNightShift;
  final String? breakdown;

  /// Midpoint of the range (for display).
  double get midpoint => (minimum + maximum) / 2;
}

/// Fetches route distance via OSRM or Mapbox and estimates price.
/// Formula: (BaseFee + (Distance * RatePerKm)) * VehicleMultiplier * NightShift(if applicable).
/// Returns a min/max range for legal flexibility.
class PriceEstimationService {
  PriceEstimationService({
    this.osrmBaseUrl = 'https://router.project-osrm.org',
    this.mapboxAccessToken,
    this.useMapbox = false,
  });

  final String osrmBaseUrl;
  final String? mapboxAccessToken;
  final bool useMapbox;

  static const _nightStartHour = 22; // 10 PM
  static const _nightEndHour = 6;   // 6 AM

  /// Returns true if current local time is in night shift (10 PM – 6 AM).
  bool get isNightShift {
    final now = DateTime.now();
    final hour = now.hour;
    if (_nightStartHour > _nightEndHour) {
      return hour >= _nightStartHour || hour < _nightEndHour;
    }
    return hour >= _nightStartHour && hour < _nightEndHour;
  }

  /// Fetches travel distance in km between two points using OSRM or Mapbox.
  Future<double?> getTravelDistanceKm({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
  }) async {
    if (useMapbox && mapboxAccessToken != null && mapboxAccessToken!.isNotEmpty) {
      return _getDistanceMapbox(
        originLng: originLng,
        originLat: originLat,
        destLng: destLng,
        destLat: destLat,
      );
    }
    return _getDistanceOsrm(
      originLng: originLng,
      originLat: originLat,
      destLng: destLng,
      destLat: destLat,
    );
  }

  Future<double?> _getDistanceOsrm({
    required double originLng,
    required double originLat,
    required double destLng,
    required double destLat,
  }) async {
    final url = '$osrmBaseUrl/route/v1/driving/'
        '${originLng.toStringAsFixed(5)},${originLat.toStringAsFixed(5)};'
        '${destLng.toStringAsFixed(5)},${destLat.toStringAsFixed(5)}'
        '?overview=false';
    try {
      final res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('OSRM timeout'),
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      final code = data?['code'] as String?;
      if (code != 'Ok') return null;
      final routes = data?['routes'] as List<dynamic>?;
      final firstRoute = (routes != null && routes.isNotEmpty) ? routes.first : null;
      final distanceMeters = firstRoute is Map<String, dynamic>
          ? firstRoute['distance'] as num?
          : null;
      if (distanceMeters == null) return null;
      return distanceMeters.toDouble() / 1000;
    } catch (_) {
      return null;
    }
  }

  Future<double?> _getDistanceMapbox({
    required double originLng,
    required double originLat,
    required double destLng,
    required double destLat,
  }) async {
    final token = mapboxAccessToken!;
    final coords = '$originLng,$originLat;$destLng,$destLat';
    final url = 'https://api.mapbox.com/directions/v5/mapbox/driving/$coords'
        '?access_token=$token&overview=false';
    try {
      final res = await http.get(Uri.parse(url)).timeout(
        const Duration(seconds: 10),
        onTimeout: () => throw Exception('Mapbox timeout'),
      );
      if (res.statusCode != 200) return null;
      final data = jsonDecode(res.body) as Map<String, dynamic>?;
      final routes = data?['routes'] as List<dynamic>?;
      final firstRoute = (routes != null && routes.isNotEmpty) ? routes.first : null;
      final distanceMeters = firstRoute is Map<String, dynamic>
          ? firstRoute['distance'] as num?
          : null;
      if (distanceMeters == null) return null;
      return distanceMeters.toDouble() / 1000;
    } catch (_) {
      return null;
    }
  }

  /// Estimates price range from current location to destination for the given vehicle type.
  ///
  /// Formula: (BaseFee + (Distance * RatePerKm)) * VehicleMultiplier * (1 + NightShiftSurcharge if 10PM–6AM).
  /// Output is a min/max range using [AppConstants.priceRangeVariance].
  Future<PriceEstimate> estimate({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required String vehicleType,
  }) async {
    final distanceKm = await getTravelDistanceKm(
      originLat: originLat,
      originLng: originLng,
      destLat: destLat,
      destLng: destLng,
    );

    final baseFee = AppConstants.basePriceByVehicleType[vehicleType] ?? 50.0;
    final ratePerKm = AppConstants.ratePerKmByVehicleType[vehicleType] ?? 3.5;
    final multiplier = AppConstants.vehicleMultiplierByType[vehicleType] ?? 1.0;
    final nightRate = AppConstants.nightShiftSurchargeRate;
    final variance = AppConstants.priceRangeVariance;

    final d = distanceKm ?? 0.0;
    final baseAmount = (baseFee + (d * ratePerKm)) * multiplier;
    final nightFactor = isNightShift ? (1.0 + nightRate) : 1.0;
    final estimated = baseAmount * nightFactor;

    final minPrice = (estimated * (1 - variance)).clamp(0.0, double.infinity);
    final maxPrice = estimated * (1 + variance);

    final breakdown = 'Base: $baseFee + (${d.toStringAsFixed(1)} km × $ratePerKm) × $multiplier'
        '${isNightShift ? ' × 1.3 (night)' : ''} → ${estimated.toStringAsFixed(0)} ± ${(variance * 100).toInt()}%';

    return PriceEstimate(
      minimum: minPrice,
      maximum: maxPrice,
      distanceKm: d,
      isNightShift: isNightShift,
      breakdown: breakdown,
    );
  }
}
