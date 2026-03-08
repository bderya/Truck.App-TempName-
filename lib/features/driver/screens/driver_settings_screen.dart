import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../providers/driver_booking_provider.dart';

/// Driver app settings. Toggle "Open to Intercity Requests" to receive long-distance jobs.
class DriverSettingsScreen extends ConsumerStatefulWidget {
  const DriverSettingsScreen({super.key});

  @override
  ConsumerState<DriverSettingsScreen> createState() => _DriverSettingsScreenState();
}

class _DriverSettingsScreenState extends ConsumerState<DriverSettingsScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _setOpenToIntercity(bool value) async {
    final truck = await ref.read(currentDriverTruckProvider.future);
    if (truck == null) {
      setState(() => _error = 'No truck registered');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final client = ref.read(supabaseClientProvider);
      await client
          .from('tow_trucks')
          .update({
            'open_to_intercity': value,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', truck.id);
      if (mounted) {
        ref.invalidate(currentDriverTruckProvider);
        ref.invalidate(driverBookingProvider);
        setState(() {
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final truckAsync = ref.watch(currentDriverTruckProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: truckAsync.when(
        data: (truck) {
          if (truck == null) {
            return const Center(
              child: Text('Önce kayıt olmanız gerekiyor.'),
            );
          }
          final openToIntercity = truck.openToIntercity;
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              SwitchListTile(
                title: const Text('Şehirler arası isteklere açık'),
                subtitle: const Text(
                  'Açıksanız uzun mesafe (şehirler arası) işler size gösterilir.',
                ),
                value: openToIntercity,
                onChanged: _loading
                    ? null
                    : (value) => _setOpenToIntercity(value),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    _error!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.error,
                        ),
                  ),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }
}
