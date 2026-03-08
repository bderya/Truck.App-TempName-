import 'package:flutter/material.dart';

import 'payment_types.dart';

/// Handles payment result and shows snackbar on failure (e.g. insufficient funds).
void handlePaymentResult<T>(
  BuildContext context,
  PaymentResult<T> result, {
  String successMessage = 'Payment successful',
  void Function(T data)? onSuccess,
}) {
  switch (result) {
    case PaymentSuccess(:final data):
      if (onSuccess != null) onSuccess(data);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(successMessage),
            backgroundColor: Colors.green,
          ),
        );
      }
      break;
    case PaymentFailure(:final reason, :final code):
      if (context.mounted) {
        _showPaymentFailureSnackBar(context, reason, code);
      }
      break;
  }
}

void _showPaymentFailureSnackBar(
  BuildContext context,
  String reason,
  String? code,
) {
  final failure = PaymentFailure(reason, code: code);
  String message = reason;
  if (failure.isInsufficientFunds) {
    message = 'Insufficient funds. Please use another card or add funds.';
  } else if (failure.isCardDeclined) {
    message = 'Card was declined. Please try another card.';
  }

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      action: SnackBarAction(
        label: 'Dismiss',
        textColor: Colors.white,
        onPressed: () =>
            ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}

/// Call when a booking is completed: run split payment (X% platform, Y% driver)
/// and show success or failure snackbar (e.g. insufficient funds, card declined).
Future<void> processBookingPaymentAndNotify({
  required BuildContext context,
  required PaymentService paymentService,
  required String cardTokenId,
  required double totalAmount,
  required String currency,
  required String bookingId,
  required String driverStripeAccountId,
  double? platformPercent,
  double? driverPercent,
}) async {
  final result = await paymentService.distributeFunds(
    cardTokenId: cardTokenId,
    totalAmount: totalAmount,
    currency: currency,
    bookingId: bookingId,
    driverStripeAccountId: driverStripeAccountId,
    platformPercent: platformPercent,
    driverPercent: driverPercent,
  );

  handlePaymentResult(
    context,
    result,
    successMessage: 'Payment completed. Funds have been split to platform and driver.',
    onSuccess: (_) {},
  );
}
