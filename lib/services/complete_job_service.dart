import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../models/models.dart';
import 'commission_service.dart';
import 'payment/payment_service.dart';
import 'payment/payment_types.dart';

/// Result of completing a job (status update, payment, availability).
class CompleteJobResult {
  const CompleteJobResult({
    required this.success,
    required this.booking,
    this.paymentCaptured = false,
    this.paymentError,
    this.driverEarnings,
    this.duration,
  });

  final bool success;
  final Booking booking;
  final bool paymentCaptured;
  final String? paymentError;
  final double? driverEarnings;
  final Duration? duration;
}

/// Handles the finale of a booking: verification, status update, payment capture, driver availability.
class CompleteJobService {
  CompleteJobService({
    SupabaseClient? client,
    PaymentService? paymentService,
    CommissionService? commissionService,
  })  : _client = client ?? Supabase.instance.client,
        _paymentService = paymentService,
        _commissionService = commissionService;

  final SupabaseClient _client;
  final PaymentService? _paymentService;
  final CommissionService? _commissionService;

  static const int _requiredDamagePhotos = 4;

  /// Verifies that delivery photos and customer signature are uploaded.
  bool verifyProofOfWork(Booking booking) {
    final photos = booking.damagePhotos ?? [];
    final hasSignature = booking.deliverySignatureUrl != null &&
        (booking.deliverySignatureUrl!.trim().isNotEmpty);
    return photos.length >= _requiredDamagePhotos && hasSignature;
  }

  /// Completes the job: verifies proof of work, updates status and ended_at,
  /// captures payment (if card token and driver account provided), sets driver available.
  Future<CompleteJobResult> completeJob(
    Booking booking, {
    String? cardTokenId,
    String? driverStripeAccountId,
  }) async {
    if (!verifyProofOfWork(booking)) {
      return CompleteJobResult(
        success: false,
        booking: booking,
        paymentError: 'Missing proof of work: need 4 damage photos and customer signature.',
      );
    }

    final driverId = booking.driverId;
    if (driverId == null) {
      return CompleteJobResult(
        success: false,
        booking: booking,
        paymentError: 'Booking has no driver assigned.',
      );
    }

    final endedAt = DateTime.now().toUtc();
    final duration = booking.createdAt != null
        ? endedAt.difference(booking.createdAt!)
        : null;

    CommissionSplit? commissionSplit;
    if (_commissionService != null && booking.price != null && booking.price! > 0) {
      commissionSplit = await _commissionService!.calculateNetEarnings(
        totalPrice: booking.price!,
        driverId: driverId,
        bookingId: booking.id,
      );
    }

    try {
      final firstUpdate = <String, dynamic>{
        'status': 'completed',
        'ended_at': endedAt.toIso8601String(),
        'updated_at': endedAt.toIso8601String(),
      };
      if (commissionSplit != null) {
        firstUpdate['driver_net_amount'] = commissionSplit.driverNetAmount;
        firstUpdate['platform_commission_percent'] = commissionSplit.commissionPercent;
      }
      await _client.from('bookings').update(firstUpdate).eq('id', booking.id);

      await _client.from('tow_trucks').update({
        'is_available': true,
        'updated_at': endedAt.toIso8601String(),
      }).eq('driver_id', driverId);

      double? driverEarnings;
      bool paymentCaptured = false;
      String? paymentError;

      if (_paymentService != null &&
          cardTokenId != null &&
          cardTokenId.isNotEmpty &&
          driverStripeAccountId != null &&
          driverStripeAccountId.isNotEmpty &&
          booking.price != null &&
          booking.price! > 0) {
        final platformPercent = commissionSplit?.platformPercent ?? AppConstants.platformCommissionRate;
        final driverPercent = commissionSplit?.driverPercent ?? (1.0 - platformPercent);

        final result = await _paymentService!.distributeFunds(
          cardTokenId: cardTokenId,
          totalAmount: booking.price!,
          currency: 'TRY',
          bookingId: booking.id.toString(),
          driverStripeAccountId: driverStripeAccountId,
          platformPercent: platformPercent,
          driverPercent: driverPercent,
        );
        if (result is PaymentSuccess<SplitBreakdown>) {
          paymentCaptured = true;
          driverEarnings = result.data.driverAmount;
        } else if (result is PaymentFailure) {
          paymentError = result.reason;
        }
      }

      final updatedBooking = booking.copyWith(
        status: 'completed',
        endedAt: endedAt,
        driverNetAmount: commissionSplit?.driverNetAmount ?? driverEarnings,
        platformCommissionPercent: commissionSplit?.commissionPercent,
      );

      return CompleteJobResult(
        success: true,
        booking: updatedBooking,
        paymentCaptured: paymentCaptured,
        paymentError: paymentError,
        driverEarnings: driverEarnings ??
            commissionSplit?.driverNetAmount ??
            (booking.price != null
                ? booking.price! * (1 - AppConstants.platformCommissionRate)
                : null),
        duration: duration,
      );
    } catch (e) {
      return CompleteJobResult(
        success: false,
        booking: booking,
        paymentError: e.toString(),
      );
    }
  }
}
