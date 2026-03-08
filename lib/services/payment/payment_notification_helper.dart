import 'package:flutter/material.dart';

import '../../core/error_messages_tr.dart';
import 'payment_types.dart';
import '../../features/booking/widgets/payment_failure_sheet.dart';

/// Handles payment result. On failure shows payment BottomSheet with [Update Payment Method] if [userId] provided.
void handlePaymentResult<T>(
  BuildContext context,
  PaymentResult<T> result, {
  String successMessage = 'Ödeme başarılı',
  void Function(T data)? onSuccess,
  int? userId,
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
    case PaymentFailure():
      if (context.mounted) {
        if (userId != null) {
          showPaymentFailureSheet(context, failure: result, userId: userId);
        } else {
          _showPaymentFailureSnackBar(context, result);
        }
      }
      break;
  }
}

void _showPaymentFailureSnackBar(BuildContext context, PaymentFailure failure) {
  final message = PaymentErrorHelper.userMessageTr(failure);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: Theme.of(context).colorScheme.error,
      action: SnackBarAction(
        label: 'Kapat',
        textColor: Colors.white,
        onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),
      ),
    ),
  );
}

/// Call when a booking is completed: run split payment (X% platform, Y% driver).
/// Pass [userId] to show payment failure sheet with Update Payment Method.
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
  int? userId,
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
    successMessage: 'Ödeme tamamlandı. Tutar platform ve sürücüye dağıtıldı.',
    onSuccess: (_) {},
    userId: userId,
  );
}
