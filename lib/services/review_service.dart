import 'package:supabase_flutter/supabase_flutter.dart';

/// Submits a review for a completed booking to the [reviews] table.
/// Trigger on [reviews] recalculates driver's average_rating.
Future<bool> submitReview({
  required SupabaseClient client,
  required int bookingId,
  required int driverId,
  required int clientId,
  required int rating,
  String? comment,
  List<String>? tags,
}) async {
  try {
    await client.from('reviews').insert({
      'booking_id': bookingId,
      'driver_id': driverId,
      'client_id': clientId,
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
      'tags': tags ?? [],
    });
    return true;
  } catch (_) {
    return false;
  }
}
