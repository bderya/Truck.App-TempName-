import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../providers/driver_booking_provider.dart';

/// Weekly audit: driver must upload 3 photos of their truck every Monday.
/// When is_inspected is false, this screen is shown to re-enable job-taking.
class WeeklyInspectionScreen extends ConsumerStatefulWidget {
  const WeeklyInspectionScreen({super.key});

  @override
  ConsumerState<WeeklyInspectionScreen> createState() => _WeeklyInspectionScreenState();
}

class _WeeklyInspectionScreenState extends ConsumerState<WeeklyInspectionScreen> {
  final List<File?> _photos = [null, null, null];
  bool _loading = false;
  String? _error;

  Future<void> _pickPhoto(int index) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('camera'.tr()),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('gallery'.tr()),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await picker.pickImage(source: source, imageQuality: 85);
    if (file == null || !mounted) return;
    setState(() {
      _photos[index] = File(file.path);
      _error = null;
    });
  }

  Future<void> _submit() async {
    if (_photos.any((p) => p == null)) {
      setState(() => _error = 'Lütfen 3 fotoğraf yükleyin');
      return;
    }

    final truck = await ref.read(currentDriverTruckProvider.future);
    if (truck == null || !mounted) {
      setState(() => _error = 'Araç bulunamadı');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final proofOfWork = ref.read(proofOfWorkServiceProvider);
      final urls = <String>[];
      for (var i = 0; i < 3; i++) {
        final url = await proofOfWork.uploadInspectionPhoto(
          truckId: truck.id,
          file: _photos[i]!,
          photoIndex: i + 1,
        );
        urls.add(url);
      }

      final client = ref.read(supabaseClientProvider);
      final res = await client.rpc(
        'submit_inspection_photos',
        params: {
          'p_tow_truck_id': truck.id,
          'p_photo_urls': urls,
        },
      );

      final map = res as Map<String, dynamic>?;
      final ok = map?['ok'] as bool?;
      if (ok != true && mounted) {
        setState(() {
          _loading = false;
          _error = map?['error'] as String? ?? 'Yükleme başarısız';
        });
        return;
      }

      ref.invalidate(currentDriverTruckProvider);
      ref.invalidate(driverBookingProvider);
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('inspection_done'.tr()),
          backgroundColor: Colors.green,
        ),
      );
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
    return Scaffold(
      appBar: AppBar(
        title: Text('weekly_inspection'.tr()),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Her pazartesi çekicinizin 3 fotoğrafını yüklemeniz gerekiyor. Tamamlayana kadar iş alamazsınız.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ...List.generate(3, (i) {
              final file = _photos[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: ListTile(
                  title: Text('${'photo_n'.tr()} ${i + 1}'),
                  subtitle: Text(file != null ? 'uploaded'.tr() : 'tap_to_upload'.tr()),
                  trailing: IconButton(
                    icon: Icon(file != null ? Icons.check_circle : Icons.add_photo_alternate),
                    onPressed: _loading ? null : () => _pickPhoto(i),
                  ),
                  tileColor: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              );
            }),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
                    ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _submit,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _loading
                  ? const SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text('send'.tr()),
            ),
          ],
        ),
      ),
    );
  }
}
