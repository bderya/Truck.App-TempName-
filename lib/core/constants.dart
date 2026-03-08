/// App-wide constants
class AppConstants {
  AppConstants._();

  static const String appName = 'Cekici';

  /// Base price (currency units) per vehicle type.
  static const Map<String, double> basePriceByVehicleType = {
    'standard': 50.0,
    'heavy': 80.0,
    'motorcycle': 30.0,
  };

  /// Rate per km (currency units) per vehicle type.
  static const Map<String, double> ratePerKmByVehicleType = {
    'standard': 3.5,
    'heavy': 5.0,
    'motorcycle': 2.0,
  };

  /// Vehicle multiplier for price estimation (e.g. heavy = 1.2).
  static const Map<String, double> vehicleMultiplierByType = {
    'standard': 1.0,
    'heavy': 1.2,
    'motorcycle': 0.9,
  };

  /// Currency symbol for display.
  static const String currencySymbol = '₺';

  /// Platform commission rate (0.0–1.0) for admin earnings.
  static const double platformCommissionRate = 0.15;

  /// Night shift surcharge (10 PM–6 AM). Multiply by (1 + this).
  static const double nightShiftSurchargeRate = 0.30;

  /// Price range: base estimate ± this fraction for min/max (e.g. 0.1 = ±10%).
  static const double priceRangeVariance = 0.15;
}
