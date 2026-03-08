import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'proof_of_work_service.dart';

/// Uploads driver onboarding docs and updates users + tow_trucks.
/// Uses same storage bucket as proof-of-work (path: onboarding/{user_id}/...).
class DriverOnboardingService {
  DriverOnboardingService({
    SupabaseClient? client,
    ProofOfWorkService? proofOfWork,
  })  : _client = client ?? Supabase.instance.client,
        _proofOfWork = proofOfWork ?? ProofOfWorkService();

  final SupabaseClient _client;
  final ProofOfWorkService _proofOfWork;

  static const _bucket = 'proof-of-work';
  static const _prefix = 'onboarding';

  /// Uploads image and returns public URL. [fileName] e.g. license.jpg, plate.jpg.
  Future<String> _uploadImage(int userId, File file, String fileName) async {
    final compressed = await _proofOfWork.compressImage(file);
    final path = '$_prefix/$userId/$fileName';
    await _client.storage.from(_bucket).upload(
          path,
          compressed,
          fileOptions: const FileOptions(upsert: true),
        );
    return _client.storage.from(_bucket).getPublicUrl(path);
  }

  /// Saves driver onboarding: updates users (full_name, license_image_url, user_type, is_verified, status)
  /// and inserts tow_trucks (driver_id, plate_number, truck_type, plate_image_url).
  /// Sets is_verified = false and status = 'pending'.
  Future<void> submitOnboarding({
    required int userId,
    required String fullName,
    required String plateNumber,
    required String truckType,
    required File licenseImageFile,
    required File vehicleRegistrationFile,
  }) async {
    final licenseUrl = await _uploadImage(userId, licenseImageFile, 'license.jpg');
    final plateUrl = await _uploadImage(userId, vehicleRegistrationFile, 'plate.jpg');

    await _client.from('users').update({
      'full_name': fullName,
      'user_type': 'driver',
      'license_image_url': licenseUrl,
      'is_verified': false,
      'status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    await _client.from('tow_trucks').insert({
      'driver_id': userId,
      'plate_number': plateNumber.trim(),
      'truck_type': truckType,
      'plate_image_url': plateUrl,
      'current_latitude': 0,
      'current_longitude': 0,
      'is_available': false,
    });
  }
}
