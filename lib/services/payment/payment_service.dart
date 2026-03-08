import 'payment_types.dart';

/// Payment service contract. Integrates with a marketplace API (e.g. Stripe Connect, Iyzico).
///
/// Security: No raw card data is stored on our servers. All card handling uses
/// tokenization (payment method / token IDs only).
abstract class PaymentService {
  /// Adds a card by tokenizing it via the gateway. Returns a [CardToken] (token ID only).
  /// Raw card data must be sent only to the gateway SDK (e.g. Stripe Elements), never to our backend.
  Future<PaymentResult<CardToken>> addCard({
    required String gatewayTokenOrPaymentMethodId,
    String? customerId,
  });

  /// Tokenize card (via gateway) and save to user_payment_methods. Use either [cardToken]
  /// from client-side SDK or [cardNumber]/[expMonth]/[expYear]/[cvc] for server-side tokenization.
  Future<PaymentResult<CardToken>> tokenizeAndSaveCard({
    required int userId,
    String? cardToken,
    String? cardNumber,
    int? expMonth,
    int? expYear,
    String? cvc,
    bool setDefault = true,
  });

  /// Pre-authorizes payment (auth only, no capture). Use for Request Tow; store returned
  /// [payment_id] on the booking and capture when job is completed.
  /// Iyzico: paymentGroup=LISTING, auth=true. Stripe: PaymentIntent capture_method=manual.
  Future<PaymentResult<String>> authorizeOnly({
    required String cardTokenId,
    required double amount,
    required String currency,
    String? customerId,
  });

  /// Processes payment for a booking. For completed bookings use [distributeFunds] to split platform/driver.
  Future<PaymentResult<String>> processPayment({
    required String cardTokenId,
    required double amount,
    required String currency,
    required String bookingId,
    String? customerId,
  });

  /// Processes a split payment: X% to platform, Y% to driver. Call when booking is completed.
  /// [platformPercent] and [driverPercent] should sum to 1.0 (e.g. 0.15 and 0.85).
  Future<PaymentResult<SplitBreakdown>> distributeFunds({
    required String cardTokenId,
    required double totalAmount,
    required String currency,
    required String bookingId,
    required String driverStripeAccountId,
    double? platformPercent,
    double? driverPercent,
    String? customerId,
  });
}
