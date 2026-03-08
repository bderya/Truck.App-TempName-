// Proof of work: pre-pickup photos and delivery signature.
// Supabase: create a storage bucket named "proof-of-work" (public or with RLS as needed)
// and allow authenticated uploads to paths: bookings/{id}/pre_pickup/* and bookings/{id}/delivery_signature.png

import 'dart:io';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Handles proof-of-work: compress images, upload to Supabase Storage,
/// update booking damage_photos and delivery_signature_url.
class ProofOfWorkService {
  ProofOfWorkService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const int _quality = 75;
  static const int _maxWidth = 1920;
  static const int _maxHeight = 1920;

  /// Compresses [file] (image) and returns a new file in temp directory.
  Future<File> compressImage(File file) async {
    final dir = await getTemporaryDirectory();
    final targetPath = p.join(
      dir.path,
      'proof_${DateTime.now().millisecondsSinceEpoch}${p.extension(file.path)}',
    );
    final result = await FlutterImageCompress.compressAndGetFile(
      file.absolute.path,
      targetPath,
      quality: _quality,
      minWidth: _maxWidth,
      minHeight: _maxHeight,
    );
    if (result == null) throw Exception('Image compression failed');
    return result;
  }

  /// Uploads [file] to storage at bookings/{bookingId}/pre_pickup/{filename}.
  /// Returns the public URL.
  Future<String> uploadPrePickupPhoto({
    required int bookingId,
    required File file,
    required int photoIndex,
  }) async {
    final compressed = await compressImage(file);
    final ext = p.extension(file.path).toLowerCase();
    if (ext.isEmpty) throw Exception('File has no extension');
    final name = 'photo_$photoIndex$ext';
    final path = 'bookings/$bookingId/pre_pickup/$name';

    await _client.storage.from('proof-of-work').upload(
          path,
          compressed,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from('proof-of-work').getPublicUrl(path);
    return url;
  }

  /// Updates booking.damage_photos with the list of public URLs.
  Future<void> setBookingDamagePhotos({
    required int bookingId,
    required List<String> urls,
  }) async {
    await _client.from('bookings').update({
      'damage_photos': urls,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }

  /// Uploads signature image bytes to storage and sets booking.delivery_signature_url.
  Future<void> uploadDeliverySignature({
    required int bookingId,
    required List<int> imageBytes,
  }) async {
    final dir = await getTemporaryDirectory();
    final path = p.join(dir.path, 'signature_${bookingId}_${DateTime.now().millisecondsSinceEpoch}.png');
    final file = File(path);
    await file.writeAsBytes(imageBytes);

    final fullPath = 'bookings/$bookingId/delivery_signature.png';
    await _client.storage.from('proof-of-work').upload(
          fullPath,
          file,
          fileOptions: const FileOptions(upsert: true),
        );

    final url = _client.storage.from('proof-of-work').getPublicUrl(fullPath);
    await _client.from('bookings').update({
      'delivery_signature_url': url,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', bookingId);
  }
}
