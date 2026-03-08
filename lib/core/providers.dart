import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_service.dart';
import '../services/auth_service.dart';
import '../services/driver_onboarding_service.dart';
import '../services/location_service.dart';
import '../services/payment/payment_service.dart';
import '../services/payment/stripe_payment_service.dart';
import '../services/complete_job_service.dart';
import '../services/chat_service.dart';
import '../services/driver_tracking_service.dart';
import '../services/price_estimation/price_estimation_service.dart';
import '../services/proof_of_work_service.dart';
import '../services/payment/payment_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});

final paymentServiceProvider = Provider<PaymentService>((ref) {
  return StripePaymentService();
});

final priceEstimationServiceProvider = Provider<PriceEstimationService>((ref) {
  return PriceEstimationService();
});

final proofOfWorkServiceProvider = Provider<ProofOfWorkService>((ref) {
  return ProofOfWorkService();
});

final completeJobServiceProvider = Provider<CompleteJobService>((ref) {
  return CompleteJobService(paymentService: ref.watch(paymentServiceProvider));
});

/// Central Supabase client for dual-app (Client + Driver). Uses [SupabaseService].
final supabaseClientProvider = Provider<SupabaseClient>((ref) => SupabaseService.client);

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final chatServiceProvider = Provider<ChatService>((ref) {
  return ChatService(client: ref.watch(supabaseClientProvider));
});

final driverTrackingServiceProvider = Provider<DriverTrackingService>((ref) {
  return DriverTrackingService(client: ref.watch(supabaseClientProvider));
});

final driverOnboardingServiceProvider = Provider<DriverOnboardingService>((ref) {
  return DriverOnboardingService(proofOfWork: ref.watch(proofOfWorkServiceProvider));
});
