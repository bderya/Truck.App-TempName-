/// Result of a payment or card operation. No raw card data is ever stored.
sealed class PaymentResult<T> {
  const PaymentResult();
}

class PaymentSuccess<T> extends PaymentResult<T> {
  const PaymentSuccess(this.data);
  final T data;
}

class PaymentFailure extends PaymentResult<Never> {
  const PaymentFailure(this.reason, {this.code});

  /// User-facing or log message.
  final String reason;

  /// Optional gateway code (e.g. insufficient_funds, card_declined).
  final String? code;

  bool get isInsufficientFunds =>
      code?.toLowerCase().contains('insufficient') == true ||
      reason.toLowerCase().contains('insufficient');
  bool get isCardDeclined =>
      code?.toLowerCase().contains('declined') == true ||
      reason.toLowerCase().contains('declined');
}

/// Maps payment failure and gateway codes to user-friendly messages (e.g. 3DS, insufficient balance).
class PaymentErrorHelper {
  PaymentErrorHelper._();

  static String userMessage(PaymentFailure failure) {
    final code = failure.code?.toLowerCase() ?? '';
    final reason = failure.reason.toLowerCase();

    if (failure.isInsufficientFunds || code.contains('insufficient') || reason.contains('insufficient')) {
      return 'Insufficient balance. Please use another card or add funds.';
    }
    if (failure.isCardDeclined || code.contains('declined') || reason.contains('declined')) {
      return 'Card was declined. Please try another card.';
    }
    if (code.contains('3d') || code.contains('3ds') || reason.contains('3d') || reason.contains('authentication')) {
      return 'Verification failed. Please try again or use another card.';
    }
    if (code.contains('expired') || reason.contains('expired')) {
      return 'Card has expired. Please update your card.';
    }
    if (code.contains('invalid') || reason.contains('invalid')) {
      return 'Invalid card details. Please check and try again.';
    }
    if (reason.isNotEmpty) return failure.reason;
    return 'Payment failed. Please try again.';
  }

  /// Turkish user-facing message for payment failures.
  static String userMessageTr(PaymentFailure failure) {
    final code = failure.code?.toLowerCase() ?? '';
    final reason = failure.reason.toLowerCase();
    if (failure.isInsufficientFunds || code.contains('insufficient') || reason.contains('insufficient')) {
      return 'Yetersiz bakiye. Lütfen başka kart deneyin veya bakiye ekleyin.';
    }
    if (failure.isCardDeclined || code.contains('declined') || reason.contains('declined')) {
      return 'Kartınız reddedildi. Lütfen başka kart deneyin.';
    }
    if (code.contains('3d') || code.contains('3ds') || reason.contains('3d') || reason.contains('authentication')) {
      return 'Doğrulama başarısız. Lütfen tekrar deneyin veya başka kart kullanın.';
    }
    if (code.contains('expired') || reason.contains('expired')) {
      return 'Kartınızın süresi dolmuş. Lütfen ödeme yöntemini güncelleyin.';
    }
    if (code.contains('invalid') || reason.contains('invalid')) {
      return 'Geçersiz kart bilgisi. Lütfen kontrol edip tekrar deneyin.';
    }
    if (reason.isNotEmpty) return failure.reason;
    return 'Ödeme işlemi başarısız. Lütfen tekrar deneyin.';
  }
}

/// Tokenized card reference. Only this is stored or sent; never raw PAN/CVC.
class CardToken {
  const CardToken({
    required this.tokenId,
    this.last4,
    this.brand,
    this.expMonth,
    this.expYear,
  });

  final String tokenId;
  final String? last4;
  final String? brand;
  final int? expMonth;
  final int? expYear;
}

/// Split breakdown for a completed payment (platform vs driver).
class SplitBreakdown {
  const SplitBreakdown({
    required this.totalAmount,
    required this.platformAmount,
    required this.driverAmount,
    required this.platformPercent,
    required this.driverPercent,
    this.paymentIntentId,
    this.driverTransferId,
  });

  final double totalAmount;
  final double platformAmount;
  final double driverAmount;
  final double platformPercent;
  final double driverPercent;
  final String? paymentIntentId;
  final String? driverTransferId;
}
