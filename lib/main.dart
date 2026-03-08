import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/providers.dart';
import 'admin_app.dart';
import 'features/admin/admin_approval_screen.dart';
import 'features/auth/providers/auth_state_provider.dart';
import 'features/auth/screens/auth_gate.dart';
import 'features/driver/driver_home_screen.dart';
import 'features/map/map_view_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'YOUR_SUPABASE_URL',
    anonKey: 'YOUR_SUPABASE_ANON_KEY',
  );

  runApp(
    const ProviderScope(
      child: kIsWeb ? AdminApp() : _MobileApp(),
    ),
  );
}

/// Mobile/desktop: app switcher (Customer, Driver, Admin approval).
class _MobileApp extends ConsumerWidget {
  const _MobileApp();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp(
      title: 'Cekici',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const AuthGate(authenticatedChild: _AppSwitcher()),
    );
  }
}

/// Allows switching between Customer and Driver app for demo.
class _AppSwitcher extends ConsumerWidget {
  const _AppSwitcher();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Cekici',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const MapViewScreen(),
                ),
              ),
              icon: const Icon(Icons.person),
              label: const Text('Customer App'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const DriverHomeScreen(),
                ),
              ),
              icon: const Icon(Icons.local_shipping),
              label: const Text('Driver App'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const AdminApprovalScreen(),
                ),
              ),
              icon: const Icon(Icons.admin_panel_settings),
              label: const Text('Admin – Approval'),
            ),
            const SizedBox(height: 32),
            TextButton.icon(
              onPressed: () async {
                await ref.read(authServiceProvider).signOut();
                ref.invalidate(authStatusProvider);
              },
              icon: const Icon(Icons.logout),
              label: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
