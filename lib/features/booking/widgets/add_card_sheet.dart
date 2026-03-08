import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../core/error_messages_tr.dart';
import '../../../services/payment/payment_types.dart' show CardToken, PaymentFailure, PaymentSuccess, PaymentErrorHelper;
import '../../auth/providers/auth_state_provider.dart';

/// Bottom sheet to add a payment method. Tokenization must be done via gateway SDK
/// (e.g. Stripe Payment Sheet); this sheet accepts a token/PM id and saves it for the user.
/// Returns true if a card was saved, false if dismissed or failed.
Future<bool> showAddCardSheet(BuildContext context, {required int userId}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => AddCardSheet(userId: userId),
  );
}

class AddCardSheet extends ConsumerStatefulWidget {
  const AddCardSheet({super.key, required this.userId});

  final int userId;

  @override
  ConsumerState<AddCardSheet> createState() => _AddCardSheetState();
}

class _AddCardSheetState extends ConsumerState<AddCardSheet> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _saveCard() async {
    final token = _controller.text.trim();
    if (token.isEmpty) {
      setState(() => _error = 'Enter a payment method token');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final result = await ref.read(paymentServiceProvider).addCard(
            gatewayTokenOrPaymentMethodId: token,
            customerId: widget.userId.toString(),
          );
      if (!mounted) return;
      if (result is PaymentSuccess<CardToken>) {
        await Supabase.instance.client.from('users').update({
          'default_card_token_id': result.data.tokenId,
          'updated_at': DateTime.now().toIso8601String(),
        }).eq('id', widget.userId);
        ref.invalidate(currentAppUserProvider);
        Navigator.of(context).pop(true);
      } else if (result is PaymentFailure) {
        setState(() {
          _loading = false;
          _error = PaymentErrorHelper.userMessageTr(result);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = ErrorMessagesTr.from(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
          Text(
            'Add payment method',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Request Tow requires a saved card. Use your gateway SDK to tokenize the card, then enter the token or payment method ID here. For testing, some gateways accept test tokens (e.g. pm_card_visa).',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Payment method / token ID',
              hintText: 'pm_... or token from gateway',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _saveCard,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save card'),
          ),
        ],
      ),
    );
  }
}
