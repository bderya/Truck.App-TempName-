import 'package:flutter/material.dart';

import '../../../core/error_messages_tr.dart';
import '../../../services/payment/payment_types.dart';
import 'add_card_sheet.dart';

/// Shows a custom BottomSheet for payment (Iyzico/API) failures with message and [Update Payment Method] button.
Future<void> showPaymentFailureSheet(
  BuildContext context, {
  required PaymentFailure failure,
  required int userId,
  VoidCallback? onUpdatePaymentMethod,
}) {
  final message = PaymentErrorHelper.userMessageTr(failure);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.error_outline,
            size: 48,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 16),
          Text(
            ErrorMessagesTr.paymentFailed,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () async {
              Navigator.of(context).pop();
              final added = await showAddCardSheet(context, userId: userId);
              if (added && context.mounted) onUpdatePaymentMethod?.call();
            },
            icon: const Icon(Icons.credit_card),
            label: const Text(ErrorMessagesTr.updatePaymentMethod),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Kapat'),
          ),
        ],
      ),
    ),
  );
}
