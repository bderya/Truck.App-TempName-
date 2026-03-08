import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_signature_pad/flutter_signature_pad.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../../../services/complete_job_service.dart';
import 'job_summary_screen.dart';

/// Delivery screen: customer signs to confirm receipt. Signature is uploaded to storage
/// and URL saved to booking.delivery_signature_url.
class DeliverySignatureScreen extends ConsumerStatefulWidget {
  const DeliverySignatureScreen({
    super.key,
    required this.booking,
    this.onComplete,
  });

  final Booking booking;
  final VoidCallback? onComplete;

  @override
  ConsumerState<DeliverySignatureScreen> createState() => _DeliverySignatureScreenState();
}

class _DeliverySignatureScreenState extends ConsumerState<DeliverySignatureScreen> {
  final GlobalKey<SignatureState> _signKey = GlobalKey<SignatureState>();
  bool _isSubmitting = false;

  Future<void> _submitSignature() async {
    final state = _signKey.currentState;
    if (state == null || !state.hasPoints) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign above first')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final ByteData? data = await state.getData();
      if (data == null) throw Exception('Could not get signature image');
      final Uint8List bytes = data.buffer.asUint8List(
        data.offsetInBytes,
        data.lengthInBytes,
      );

      await ref.read(proofOfWorkServiceProvider).uploadDeliverySignature(
            bookingId: widget.booking.id,
            imageBytes: bytes,
          );

      if (!mounted) return;

      final res = await Supabase.instance.client
          .from('bookings')
          .select()
          .eq('id', widget.booking.id)
          .single();
      final updatedBooking = Booking.fromJson(res as Map<String, dynamic>);

      final completeService = ref.read(completeJobServiceProvider);
      final result = await completeService.completeJob(
        updatedBooking,
        cardTokenId: null,
        driverStripeAccountId: null,
      );

      if (!mounted) return;
      if (result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Job completed'), backgroundColor: Colors.green),
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => JobSummaryScreen(
              result: result,
              onDone: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.paymentError ?? 'Could not complete job')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _clear() {
    _signKey.currentState?.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery confirmation'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Customer signature',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Have the customer sign below to confirm delivery.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade100,
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    height: 220,
                    child: Signature(
                      key: _signKey,
                      color: Colors.black,
                      strokeWidth: 3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _isSubmitting ? null : _clear,
                    child: const Text('Clear'),
                  ),
                ],
              ),
              const Spacer(),
              FilledButton(
                onPressed: _isSubmitting ? null : _submitSignature,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Confirm delivery'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
