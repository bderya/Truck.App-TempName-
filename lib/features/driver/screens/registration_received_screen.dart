import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

/// Shown after driver submits onboarding. Lottie animation + message. App remains locked until is_verified.
class RegistrationReceivedScreen extends StatelessWidget {
  const RegistrationReceivedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 200,
                child: Lottie.asset(
                  'assets/lottie/success.json',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Icon(
                    Icons.check_circle,
                    size: 120,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Kayıt Alındı',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'Başvurunuz inceleniyor. Onaylandığında size bildireceğiz. Bu süreçte uygulamanın diğer özellikleri kullanılamaz.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.8),
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              FilledButton(
                onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                ),
                child: const Text('Tamam'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
