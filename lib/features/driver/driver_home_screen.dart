import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_map_screen.dart';
import 'providers/driver_booking_provider.dart';
import 'providers/driver_onboarding_provider.dart';
import 'screens/driver_onboarding_screen.dart';
import 'widgets/verification_in_progress_screen.dart';
import '../../auth/providers/auth_state_provider.dart';

/// Driver app entry: sign-in check, then onboarding / Under Review / job map.
/// Uses Supabase Auth; after login, new drivers go through onboarding (Full Name, Plate, Truck Type, License + Registration photos).
/// Saves to users (is_verified: false, status: 'pending') and tow_trucks. Blocks job map until admin sets status to 'approved'.
class DriverHomeScreen extends ConsumerWidget {
  const DriverHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentAppUserProvider);
    final truckAsync = ref.watch(currentAuthUserTowTruckProvider);

    return userAsync.when(
      data: (user) {
        if (user == null) {
          return _SignInRequired();
        }

        return truckAsync.when(
          data: (truck) {
            if (truck == null) {
              return _DriverRegistrationPrompt(
                userName: user.fullName,
                onStart: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DriverOnboardingScreen(initialFullName: user.fullName),
                    ),
                  );
                },
              );
            }
            if (!user.isVerified) {
              return VerificationInProgressScreen(statusLabel: user.status);
            }
            _setDriverIdOnce(ref, user.id);
            return const DriverMapScreen();
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (_, __) => const DriverOnboardingScreen(),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _SignInRequired(),
    );
  }

  void _setDriverIdOnce(WidgetRef ref, int userId) {
    if (ref.read(driverIdProvider) != userId) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(driverIdProvider.notifier).state = userId;
      });
    }
  }
}

class _DriverRegistrationPrompt extends StatelessWidget {
  const _DriverRegistrationPrompt({required this.userName, required this.onStart});

  final String userName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver - Cekici')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.how_to_reg,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 24),
                Text(
                  'Register as a driver',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Complete the form with your details, plate number, truck type, and photos of your license and vehicle registration.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.app_registration),
                  label: const Text('Start registration'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SignInRequired extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Driver - Cekici')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.login,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
                ),
                const SizedBox(height: 24),
                Text(
                  'Sign in required',
                  style: Theme.of(context).textTheme.titleLarge,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Use the main app to sign in with your phone, then open Driver App again.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
