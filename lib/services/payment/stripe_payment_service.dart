import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/constants.dart';
import 'payment_types.dart';
import 'payment_service.dart';

/// Stripe-based payment service. Card tokenization and charges are performed
/// server-side (Supabase Edge Function or your API). This client only sends
/// token IDs and never handles raw card data.
class StripePaymentService implements PaymentService {
  StripePaymentService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const _rpcProcessPayment = 'payment_process';
  static const _rpcAddCard = 'payment_add_card';
  static const _rpcDistributeFunds = 'payment_distribute_funds';

  @override
  Future<PaymentResult<CardToken>> addCard({
    required String gatewayTokenOrPaymentMethodId,
    String? customerId,
  }) async {
    try {
      final res = await _client.rpc(
        _rpcAddCard,
        params: {
          'p_payment_method_id': gatewayTokenOrPaymentMethodId,
          if (customerId != null) 'p_customer_id': customerId,
        },
      ) as Map<String, dynamic>?;

      if (res == null || res['ok'] != true) {
        return PaymentFailure(
          res?['error'] as String? ?? 'Failed to add card',
          code: res?['code'] as String?,
        );
      }

      final token = CardToken(
        tokenId: res['token_id'] as String,
        last4: res['last4'] as String?,
        brand: res['brand'] as String?,
        expMonth: res['exp_month'] as int?,
        expYear: res['exp_year'] as int?,
      );
      return PaymentSuccess(token);
    } catch (e) {
      return PaymentFailure(
        e.toString(),
        code: 'add_card_error',
      );
    }
  }

  @override
  Future<PaymentResult<String>> processPayment({
    required String cardTokenId,
    required double amount,
    required String currency,
    required String bookingId,
    String? customerId,
  }) async {
    try {
      final res = await _client.rpc(
        _rpcProcessPayment,
        params: {
          'p_card_token_id': cardTokenId,
          'p_amount': amount,
          'p_currency': currency,
          'p_booking_id': bookingId,
          if (customerId != null) 'p_customer_id': customerId,
        },
      ) as Map<String, dynamic>?;

      if (res == null || res['ok'] != true) {
        return PaymentFailure(
          res?['error'] as String? ?? 'Payment failed',
          code: res?['code'] as String?,
        );
      }

      return PaymentSuccess(res['payment_intent_id'] as String);
    } catch (e) {
      return PaymentFailure(
        e.toString(),
        code: 'process_payment_error',
      );
    }
  }

  @override
  Future<PaymentResult<SplitBreakdown>> distributeFunds({
    required String cardTokenId,
    required double totalAmount,
    required String currency,
    required String bookingId,
    required String driverStripeAccountId,
    double? platformPercent,
    double? driverPercent,
    String? customerId,
  }) async {
    final platformPct = platformPercent ?? AppConstants.platformCommissionRate;
    final driverPct = driverPercent ?? (1.0 - platformPct);

    try {
      final res = await _client.rpc(
        _rpcDistributeFunds,
        params: {
          'p_card_token_id': cardTokenId,
          'p_total_amount': totalAmount,
          'p_currency': currency,
          'p_booking_id': bookingId,
          'p_driver_stripe_account_id': driverStripeAccountId,
          'p_platform_percent': platformPct,
          'p_driver_percent': driverPct,
          if (customerId != null) 'p_customer_id': customerId,
        },
      ) as Map<String, dynamic>?;

      if (res == null || res['ok'] != true) {
        return PaymentFailure(
          res?['error'] as String? ?? 'Split payment failed',
          code: res?['code'] as String?,
        );
      }

      final data = res['breakdown'] as Map<String, dynamic>? ?? res;
      final breakdown = SplitBreakdown(
        totalAmount: (data['total_amount'] as num?)?.toDouble() ?? totalAmount,
        platformAmount: (data['platform_amount'] as num?)?.toDouble() ?? totalAmount * platformPct,
        driverAmount: (data['driver_amount'] as num?)?.toDouble() ?? totalAmount * driverPct,
        platformPercent: platformPct,
        driverPercent: driverPct,
        paymentIntentId: data['payment_intent_id'] as String?,
        driverTransferId: data['driver_transfer_id'] as String?,
      );
      return PaymentSuccess(breakdown);
    } catch (e) {
      return PaymentFailure(
        e.toString(),
        code: 'distribute_funds_error',
      );
    }
  }
}
