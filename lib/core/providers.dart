import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/location_service.dart';
import '../services/payment/payment_service.dart';
import '../services/payment/stripe_payment_service.dart';
import '../services/price_estimation/price_estimation_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return StripePaymentService();
});

final priceEstimationServiceProvider = Provider<PriceEstimationService>((ref) {
  return PriceEstimationService();
});
