import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';
import 'providers/driver_booking_provider.dart';
import 'screens/driver_settings_screen.dart';
import 'screens/driver_wallet_screen.dart';
import 'screens/job_navigation_screen.dart';
import 'screens/weekly_inspection_screen.dart';
import 'widgets/job_request_overlay.dart';
import 'widgets/online_offline_toggle.dart';

/// Driver app screen. Shows job request overlay when a new pending booking
/// is available nearby (within 10km, matching truck type).
/// Online/Offline toggle updates tow_trucks.is_available and location stream.
class DriverMapScreen extends ConsumerStatefulWidget {
  const DriverMapScreen({super.key});

  @override
  ConsumerState<DriverMapScreen> createState() => _DriverMapScreenState();
}

class _DriverMapScreenState extends ConsumerState<DriverMapScreen> {
  bool _availabilityStreamStarted = false;

  @override
  void dispose() {
    ref.read(locationServiceProvider).stopLocationStream();
    super.dispose();
  }

  void _ensureAvailabilityStreamIfOnline(TowTruck? truck) {
    if (truck == null || !truck.isAvailable) {
      _availabilityStreamStarted = false;
      return;
    }
    if (_availabilityStreamStarted) return;
    _availabilityStreamStarted = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(locationServiceProvider).startLocationStreamToSupabase(
        towTruckId: truck.id,
        intervalSeconds: 10,
      );
    });
  }

  Future<void> _onOnlineOfflineChanged(bool toOnline) async {
    final truck = ref.read(currentDriverTruckProvider).valueOrNull;
    final driverId = ref.read(driverIdProvider);
    if (truck == null || driverId == null) return;

    final onlineService = ref.read(driverOnlineServiceProvider);
    final locationService = ref.read(locationServiceProvider);

    if (!toOnline) {
      final hasActive = await onlineService.hasActiveJob(driverId);
      if (hasActive && mounted) {
        showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text('offline_cannot'.tr()),
            content: Text('complete_current_job_first'.tr()),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text('ok'.tr()),
              ),
            ],
          ),
        );
        return;
      }
      setState(() => _availabilityStreamStarted = false);
    } else {
      setState(() => _availabilityStreamStarted = true);
    }

    await onlineService.setOnline(
      towTruckId: truck.id,
      online: toOnline,
      startLocationStream: (id) => locationService.startLocationStreamToSupabase(
        towTruckId: id,
        intervalSeconds: 10,
      ),
      stopLocationStream: locationService.stopLocationStream,
    );
    if (mounted) ref.invalidate(currentDriverTruckProvider);
  }

  @override
  Widget build(BuildContext context) {
    final pendingJob = ref.watch(driverBookingProvider);
    final driverId = ref.watch(driverIdProvider);
    final truckAsync = ref.watch(currentDriverTruckProvider);
    final userAsync = ref.watch(currentDriverUserProvider);
    final truck = truckAsync.valueOrNull;
    final user = userAsync.valueOrNull;
    final needsInspection = truck != null && !truck.isInspected;
    final underReview = user?.isUnderReview == true;
    final isOnline = truck?.isAvailable ?? false;

    _ensureAvailabilityStreamIfOnline(truck);

    return Scaffold(
      appBar: AppBar(
        title: Text('driver_title'.tr()),
        actions: [
          if (driverId != null) ...[
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DriverSettingsScreen(),
                  ),
                );
              },
              tooltip: 'settings'.tr(),
            ),
            IconButton(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const DriverWalletScreen(),
                  ),
                );
              },
              tooltip: 'earnings'.tr(),
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
          if (needsInspection)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Theme.of(context).colorScheme.errorContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Theme.of(context).colorScheme.onErrorContainer),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                'weekly_inspection_required'.tr(),
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      color: Theme.of(context).colorScheme.onErrorContainer,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        FilledButton.tonal(
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const WeeklyInspectionScreen(),
                              ),
                            );
                          },
                          child: Text('upload_photos'.tr()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          if (underReview && !needsInspection)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Material(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(Icons.rate_review, color: Theme.of(context).colorScheme.onSecondaryContainer),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'account_under_review'.tr(),
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.local_shipping,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 24),
                if (driverId != null && truck != null)
                  OnlineOfflineToggle(
                    isOnline: isOnline,
                    onChanged: _onOnlineOfflineChanged,
                    enabled: !needsInspection && !underReview,
                  )
                else
                  const SizedBox.shrink(),
                if (driverId != null && truck != null) const SizedBox(height: 24),
                Text(
                  'waiting_for_jobs'.tr(),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  driverId != null
                      ? 'notified_when_nearby'.tr()
                      : 'set_driver_id_to_receive'.tr(),
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
      setState(() => _availabilityStreamStarted = false);
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
          content: Text('job_accepted'.tr()),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('failed_accept_another_driver'.tr()),
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
              hintText: 'driver_user_id'.tr(),
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
          child: Text('set'.tr()),
        ),
      ],
    );
  }
}
