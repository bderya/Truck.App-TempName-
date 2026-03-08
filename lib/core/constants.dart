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
}
