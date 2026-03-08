import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_map_screen.dart';
import 'providers/driver_booking_provider.dart';
import 'widgets/verification_in_progress_screen.dart';

/// Driver app entry: shows Verification in Progress when not verified,
/// otherwise the job map (DriverMapScreen).
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final driverId = ref.watch(driverIdProvider);
    final userAsync = ref.watch(currentDriverUserProvider);

    if (driverId == null) {
      return const DriverMapScreen();
    }

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return const DriverMapScreen();
        }
        if (!user.isVerified) {
          return VerificationInProgressScreen(statusLabel: user.status);
        }
        return const DriverMapScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const DriverMapScreen(),
    );
  }
}
