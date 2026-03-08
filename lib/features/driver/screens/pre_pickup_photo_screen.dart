import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';

/// Proof of work: driver must take 4 mandatory photos of the vehicle before starting towing.
/// "Start Towing" is disabled until all 4 photos are uploaded.
class PrePickupPhotoScreen extends ConsumerStatefulWidget {
  const PrePickupPhotoScreen({
    super.key,
    required this.booking,
    required this.onStartTowing,
  });

  final Booking booking;
  final VoidCallback onStartTowing;

  @override
  ConsumerState<PrePickupPhotoScreen> createState() => _PrePickupPhotoScreenState();
}

class _PrePickupPhotoScreenState extends ConsumerState<PrePickupPhotoScreen> {
  static const int _requiredCount = 4;
  final List<String?> _photoUrls = List.filled(_requiredCount, null);
  final List<File?> _localFiles = List.filled(_requiredCount, null);
  final ImagePicker _picker = ImagePicker();
  int? _uploadingIndex;

  List<String> get _uploadedUrls =>
      _photoUrls.whereType<String>().toList();

  bool get _allPhotosUploaded => _uploadedUrls.length >= _requiredCount;

  Future<void> _takePhoto(int index) async {
    final XFile? file = await _picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;

    setState(() {
      _localFiles[index] = File(file.path);
      _uploadingIndex = index;
    });

    try {
      final service = ref.read(proofOfWorkServiceProvider);
      final url = await service.uploadPrePickupPhoto(
        bookingId: widget.booking.id,
        file: File(file.path),
        photoIndex: index + 1,
      );
      if (!mounted) return;
      setState(() {
        _photoUrls[index] = url;
        _uploadingIndex = null;
      });
      await _syncDamagePhotosToBooking();
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingIndex = null);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    }
  }

  Future<void> _syncDamagePhotosToBooking() async {
    if (_uploadedUrls.length < _requiredCount) return;
    try {
      await ref.read(proofOfWorkServiceProvider).setBookingDamagePhotos(
            bookingId: widget.booking.id,
            urls: _uploadedUrls,
          );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pre-pickup photos'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Take 4 photos of the vehicle from different angles (front, back, left, right).',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              Expanded(
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: 0.85,
                  ),
                  itemCount: _requiredCount,
                  itemBuilder: (context, index) {
                    return _PhotoSlot(
                      label: _angleLabel(index),
                      imageFile: _localFiles[index],
                      imageUrl: _photoUrls[index],
                      isLoading: _uploadingIndex == index,
                      onTap: () => _takePhoto(index),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _allPhotosUploaded ? () => widget.onStartTowing() : null,
                child: Text(
                  _allPhotosUploaded
                      ? 'Start Towing'
                      : 'Take ${_requiredCount - _uploadedUrls.length} more photo(s)',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _angleLabel(int index) {
    const labels = ['Front', 'Back', 'Left side', 'Right side'];
    return labels[index];
  }
}

class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({
    required this.label,
    this.imageFile,
    this.imageUrl,
    required this.isLoading,
    required this.onTap,
  });

  final String label;
  final File? imageFile;
  final String? imageUrl;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isLoading ? null : onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (imageFile != null || imageUrl != null)
                    Image(
                      image: imageFile != null
                          ? FileImage(imageFile!)
                          : NetworkImage(imageUrl!) as ImageProvider,
                      fit: BoxFit.cover,
                    )
                  else
                    Container(
                      color: Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.add_a_photo,
                        size: 48,
                        color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                  if (imageUrl != null)
                    Positioned(
                      top: 4,
                      right: 4,
                      child: Icon(
                        Icons.check_circle,
                        color: Colors.green,
                        size: 28,
                      ),
                    ),
                  if (isLoading)
                    Container(
                      color: Colors.black38,
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
