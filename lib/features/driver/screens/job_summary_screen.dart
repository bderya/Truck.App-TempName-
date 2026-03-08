import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../services/complete_job_service.dart';

/// Post-job summary shown to the driver: total earned, time taken, payment status.
class JobSummaryScreen extends StatelessWidget {
  const JobSummaryScreen({
    super.key,
    required this.result,
    this.onDone,
  });

  final CompleteJobResult result;
  final VoidCallback? onDone;

  static String _formatDuration(Duration? d) {
    if (d == null) return '—';
    if (d.inHours > 0) {
      return '${d.inHours}h ${d.inMinutes.remainder(60)}m';
    }
    return '${d.inMinutes}m';
  }

  @override
  Widget build(BuildContext context) {
    final booking = result.booking;
    final earned = result.driverEarnings ??
        (booking.price != null
            ? booking.price! * (1 - AppConstants.platformCommissionRate)
            : 0.0);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job complete'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.check_circle,
                color: Colors.green,
                size: 72,
              ),
              const SizedBox(height: 24),
              Text(
                'Thanks for completing the job',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      _SummaryRow(
                        label: 'Total earned',
                        value: '${earned.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                        valueStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                      ),
                      const Divider(height: 24),
                      _SummaryRow(
                        label: 'Time taken',
                        value: _formatDuration(result.duration),
                      ),
                      if (result.paymentCaptured) ...[
                        const Divider(height: 24),
                        _SummaryRow(
                          label: 'Payment',
                          value: 'Captured',
                          trailing: Icon(Icons.check_circle, color: Colors.green.shade700, size: 20),
                        ),
                      ] else if (result.paymentError != null) ...[
                        const Divider(height: 24),
                        _SummaryRow(
                          label: 'Payment',
                          value: 'Not captured',
                          valueStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.error,
                              ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            result.paymentError!,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context).colorScheme.error,
                                ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const Spacer(),
              FilledButton(
                onPressed: () => onDone?.call(),
                child: const Text('Done'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
    this.trailing,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: valueStyle ?? Theme.of(context).textTheme.titleMedium,
            ),
            if (trailing != null) ...[
              const SizedBox(width: 8),
              trailing!,
            ],
          ],
        ),
      ],
    );
  }
}
