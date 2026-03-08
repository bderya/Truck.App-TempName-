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

  /// Maps tow_truck_style to schema truck_type (standard/heavy/motorcycle).
  static String _mapStyleToTruckType(String towTruckStyle) {
    switch (towTruckStyle) {
      case 'crane':
        return 'heavy';
      case 'sliding_bed':
      case 'fixed':
      default:
        return 'standard';
    }
  }

  /// Saves driver onboarding: users (full_name, national_id, selfie, license, iban, tax_id, ...)
  /// and tow_trucks (plate_number, truck_type, tow_truck_style, max_weight_capacity_kg, plate_image_url).
  /// Sets is_verified = false and status = 'pending'.
  Future<void> submitOnboarding({
    required int userId,
    required String fullName,
    required String nationalId,
    required File selfieWithLicenseFile,
    required String plateNumber,
    required String towTruckStyle,
    required int? maxWeightCapacityKg,
    required File licenseImageFile,
    required File vehicleRegistrationFile,
    String? iban,
    String? legalEntityTaxId,
  }) async {
    final licenseUrl = await _uploadImage(userId, licenseImageFile, 'license.jpg');
    final plateUrl = await _uploadImage(userId, vehicleRegistrationFile, 'plate.jpg');
    final selfieUrl = await _uploadImage(userId, selfieWithLicenseFile, 'selfie_with_license.jpg');
    final truckType = _mapStyleToTruckType(towTruckStyle);

    await _client.from('users').update({
      'full_name': fullName,
      'user_type': 'driver',
      'national_id': nationalId.trim(),
      'selfie_with_license_url': selfieUrl,
      'license_image_url': licenseUrl,
      'iban': iban?.trim().isEmpty == true ? null : iban?.trim(),
      'legal_entity_tax_id': legalEntityTaxId?.trim().isEmpty == true ? null : legalEntityTaxId?.trim(),
      'is_verified': false,
      'status': 'pending',
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', userId);

    await _client.from('tow_trucks').insert({
      'driver_id': userId,
      'plate_number': plateNumber.trim(),
      'truck_type': truckType,
      'tow_truck_style': towTruckStyle,
      'max_weight_capacity_kg': maxWeightCapacityKg,
      'plate_image_url': plateUrl,
      'current_latitude': 0,
      'current_longitude': 0,
      'is_available': false,
    });
  }
}
