import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/card_input_formatters.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../../../services/payment/payment_types.dart';
import '../widgets/add_card_sheet.dart';

/// Payment Methods screen: list saved cards and add new with masked Card Number, Expiry, CVV.
class PaymentMethodsScreen extends ConsumerStatefulWidget {
  const PaymentMethodsScreen({super.key});

  @override
  ConsumerState<PaymentMethodsScreen> createState() => _PaymentMethodsScreenState();
}

class _PaymentMethodsScreenState extends ConsumerState<PaymentMethodsScreen> {
  final _cardNumberController = TextEditingController();
  final _expiryController = TextEditingController();
  final _cvvController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _cardNumberController.dispose();
    _expiryController.dispose();
    _cvvController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    final digits = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final exp = _expiryController.text.replaceAll(RegExp(r'\D'), '');
    final cvv = _cvvController.text.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 13 &&
        exp.length == 4 &&
        cvv.length >= 3 &&
        cvv.length <= 4;
  }

  Future<void> _submitCard() async {
    if (!_canSubmit || _loading) return;

    final user = await ref.read(currentAppUserProvider.future);
    if (user == null) {
      setState(() => _error = 'Please sign in to add a card');
      return;
    }

    final cardNumber = _cardNumberController.text.replaceAll(RegExp(r'\D'), '');
    final exp = _expiryController.text.replaceAll(RegExp(r'\D'), '');
    final month = exp.length >= 2 ? int.tryParse(exp.substring(0, 2)) : null;
    final year = exp.length == 4 ? int.tryParse(exp.substring(2, 4)) : null;
    final yearFull = year != null ? (year < 50 ? 2000 + year : 1900 + year) : null;
    final cvv = _cvvController.text.replaceAll(RegExp(r'\D'), '');

    setState(() {
      _error = null;
      _loading = true;
    });

    final result = await ref.read(paymentServiceProvider).tokenizeAndSaveCard(
          userId: user.id,
          cardNumber: cardNumber,
          expMonth: month,
          expYear: yearFull,
          cvc: cvv,
          setDefault: true,
        );

    if (!mounted) return;

    if (result is PaymentSuccess<CardToken>) {
      ref.invalidate(userPaymentMethodsProvider);
      ref.invalidate(currentAppUserProvider);
      await ref.read(supabaseClientProvider).from('users').update({
        'default_card_token_id': result.data.tokenId,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', user.id);
      _cardNumberController.clear();
      _expiryController.clear();
      _cvvController.clear();
      setState(() {
        _loading = false;
        _error = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Card saved securely')),
        );
      }
    } else {
      final failure = result as PaymentFailure;
      setState(() {
        _loading = false;
        _error = PaymentErrorHelper.userMessageTr(failure);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final methodsAsync = ref.watch(userPaymentMethodsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment Methods'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Saved cards',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          methodsAsync.when(
            data: (list) => list.isEmpty
                ? Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'No cards yet. Add one below.',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                          ),
                    ),
                  )
                : Column(
                    children: list
                        .map(
                          (pm) => Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(
                                Icons.credit_card,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                              title: Text(pm.displayLabel),
                              subtitle: pm.isDefault
                                  ? const Text('Default', style: TextStyle(fontSize: 12))
                                  : null,
                              trailing: pm.isDefault
                                  ? const Icon(Icons.check_circle, color: Colors.green, size: 20)
                                  : null,
                            ),
                          ),
                        )
                        .toList(),
                  ),
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 24),
          Text(
            'Add new card',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _cardNumberController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              CardNumberInputFormatter(),
              LengthLimitingTextInputFormatter(19),
            ],
            decoration: const InputDecoration(
              labelText: 'Card number',
              hintText: '0000 0000 0000 0000',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.credit_card),
            ),
            onChanged: (_) => setState(() => _error = null),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _expiryController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    ExpiryInputFormatter(),
                    LengthLimitingTextInputFormatter(5),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'Expiry',
                    hintText: 'MM/YY',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _cvvController,
                  keyboardType: TextInputType.number,
                  obscureText: true,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    CvvInputFormatter(maxLength: 4),
                    LengthLimitingTextInputFormatter(4),
                  ],
                  decoration: const InputDecoration(
                    labelText: 'CVV',
                    hintText: '123',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() => _error = null),
                ),
              ),
            ],
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
            onPressed: _canSubmit && !_loading ? _submitCard : null,
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Save card securely'),
          ),
          const SizedBox(height: 16),
          Text(
            'Card data is tokenized by the payment provider and never stored on our servers.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ],
      ),
    );
  }
}
