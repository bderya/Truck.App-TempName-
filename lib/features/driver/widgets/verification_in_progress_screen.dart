import 'package:flutter/material.dart';

/// Shown when driver is not verified. Blocks access to the job map.
class VerificationInProgressScreen extends StatelessWidget {
  const VerificationInProgressScreen({
    super.key,
    this.statusLabel,
  });

  /// Optional status from backend (pending, approved, rejected).
  final String? statusLabel;

  @override
  Widget build(BuildContext context) {
    final status = statusLabel ?? 'pending';
    final isRejected = status == 'rejected';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver - Cekici'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isRejected ? Icons.cancel_outlined : Icons.hourglass_empty,
                  size: 80,
                  color: isRejected
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 24),
                Text(
                  isRejected ? 'Verification Rejected' : 'Verification in Progress',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  isRejected
                      ? 'Your driver account could not be approved. Please contact support if you believe this is an error.'
                      : 'Your documents are under review. You will be notified when your account is approved and can access the job map.',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.8),
                      ),
                  textAlign: TextAlign.center,
                ),
                if (status != 'rejected') ...[
                  const SizedBox(height: 24),
                  Text(
                    'Status: ${status == 'pending' ? 'Pending review' : status}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
