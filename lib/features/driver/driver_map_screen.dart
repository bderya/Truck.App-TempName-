import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'providers/driver_booking_provider.dart';
import 'screens/driver_wallet_screen.dart';
import 'screens/job_navigation_screen.dart';
import 'widgets/job_request_overlay.dart';

/// Driver app screen. Shows job request overlay when a new pending booking
/// is available nearby (within 10km, matching truck type).
class DriverMapScreen extends ConsumerWidget {
  const DriverMapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingJob = ref.watch(driverBookingProvider);
    final driverId = ref.watch(driverIdProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Driver - Cekici'),
        actions: [
          if (driverId != null) ...[
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DriverWalletScreen(),
                  ),
                );
              },
              tooltip: 'Earnings',
            ),
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  'ID: $driverId',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ],
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  'Waiting for job requests',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  driverId != null
                      ? 'You will be notified when a new job is available nearby'
                      : 'Set your driver ID to receive job requests',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                if (driverId == null) ...[
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: _DriverIdInput(ref: ref),
                  ),
                ],
              ],
            ),
          ),
          if (pendingJob != null)
            JobRequestOverlay(
              booking: pendingJob.booking,
              pickupDistanceKm: pendingJob.pickupDistanceKm,
              onAccept: () => _onAccept(context, ref, pendingJob),
              onDecline: () => _onDecline(ref),
            ),
        ],
      ),
    );
  }

  Future<void> _onAccept(
    BuildContext context,
    WidgetRef ref,
    PendingJobRequest pendingJob,
  ) async {
    final success =
        await ref.read(driverBookingProvider.notifier).acceptJob();

    if (!context.mounted) return;
    if (success) {
      final locationService = ref.read(locationServiceProvider);
      final towTruckId = ref.read(currentDriverTruckProvider).valueOrNull?.id;
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => JobNavigationScreen(
            booking: pendingJob.booking,
            towTruckId: towTruckId,
            locationService: locationService,
          ),
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Job accepted!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to accept. Another driver may have taken it.'),
        ),
      );
    }
  }

  void _onDecline(WidgetRef ref) {
    ref.read(driverBookingProvider.notifier).declineJob();
  }
}

class _DriverIdInput extends ConsumerStatefulWidget {
  const _DriverIdInput({required this.ref});

  final WidgetRef ref;

  @override
  ConsumerState<_DriverIdInput> createState() => _DriverIdInputState();
}

class _DriverIdInputState extends ConsumerState<_DriverIdInput> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            focusNode: _focusNode,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'Driver user ID',
              border: OutlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: () {
            final id = int.tryParse(_controller.text.trim());
            if (id != null) {
              ref.read(driverIdProvider.notifier).state = id;
              _focusNode.unfocus();
            }
          },
          child: const Text('Set'),
        ),
      ],
    );
  }
}
