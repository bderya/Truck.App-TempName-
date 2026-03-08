import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'complete_profile_screen.dart';
import 'phone_input_screen.dart';

/// Root auth gate: shows PhoneInput, CompleteProfile, or [authenticatedChild] based on session and profile.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key, required this.authenticatedChild});

  final Widget authenticatedChild;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusAsync = ref.watch(authStatusProvider);

    return statusAsync.when(
      data: (status) {
        switch (status) {
          case AuthStatus.unauthenticated:
            return const PhoneInputScreen();
          case AuthStatus.needsProfile:
            final phone = Supabase.instance.client.auth.currentUser?.phone;
            if (phone == null || phone.isEmpty) {
              return const PhoneInputScreen();
            }
            return CompleteProfileScreen(phoneE164: phone);
          case AuthStatus.authenticated:
          case AuthStatus.initial:
            return authenticatedChild;
        }
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const PhoneInputScreen(),
    );
  }
}
