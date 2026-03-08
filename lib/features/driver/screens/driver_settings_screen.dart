import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale_helper.dart';
import '../../../core/providers.dart';
import '../../legal/legal_document_screen.dart';
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
        title: Text('settings'.tr()),
      ),
      body: truckAsync.when(
        data: (truck) {
          if (truck == null) {
            return Center(
              child: Text('settings_register_first'.tr()),
            );
          }
          final openToIntercity = truck.openToIntercity;
          final isTurkish = context.locale.languageCode == 'tr';
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              ListTile(
                title: Text('language'.tr()),
                subtitle: Text(
                  isTurkish ? 'language_turkish'.tr() : 'language_english'.tr(),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _showLanguagePicker(context),
              ),
              ListTile(
                leading: const Icon(Icons.privacy_tip_outlined),
                title: const Text('Gizlilik Politikası'),
                subtitle: const Text('KVKK aydınlatma metni'),
                trailing: const Icon(Icons.open_in_new, size: 18),
                onTap: () => LegalDocumentScreen.open(context, assetPath: 'assets/legal/kvkk.html', title: 'Gizlilik Politikası'),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text('open_to_intercity'.tr()),
                subtitle: Text('intercity_subtitle'.tr()),
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
        loading: const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Hata: $e')),
      ),
    );
  }

  void _showLanguagePicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'language'.tr(),
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ListTile(
              title: Text('language_turkish'.tr()),
              onTap: () async {
                Navigator.pop(ctx);
                await LocaleHelper.setLocale('tr', 'TR');
                if (context.mounted) {
                  await context.setLocale(const Locale('tr', 'TR'));
                }
              },
            ),
            ListTile(
              title: Text('language_english'.tr()),
              onTap: () async {
                Navigator.pop(ctx);
                await LocaleHelper.setLocale('en', 'US');
                if (context.mounted) {
                  await context.setLocale(const Locale('en', 'US'));
                }
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
