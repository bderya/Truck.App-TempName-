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
