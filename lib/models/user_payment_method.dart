/// One tokenized payment method stored for a user (from user_payment_methods table).
class UserPaymentMethod {
  const UserPaymentMethod({
    required this.id,
    required this.userId,
    required this.cardToken,
    this.last4,
    this.brand,
    this.expMonth,
    this.expYear,
    this.isDefault = false,
    this.createdAt,
  });

  final int id;
  final int userId;
  final String cardToken;
  final String? last4;
  final String? brand;
  final int? expMonth;
  final int? expYear;
  final bool isDefault;
  final DateTime? createdAt;

  static UserPaymentMethod fromJson(Map<String, dynamic> json) {
    return UserPaymentMethod(
      id: json['id'] as int,
      userId: json['user_id'] as int,
      cardToken: json['card_token'] as String,
      last4: json['last4'] as String?,
      brand: json['brand'] as String?,
      expMonth: json['exp_month'] as int?,
      expYear: json['exp_year'] as int?,
      isDefault: json['is_default'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'card_token': cardToken,
        if (last4 != null) 'last4': last4,
        if (brand != null) 'brand': brand,
        if (expMonth != null) 'exp_month': expMonth,
        if (expYear != null) 'exp_year': expYear,
        'is_default': isDefault,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };

  String get displayLabel {
    final exp = (expMonth != null && expYear != null)
        ? '  ${expMonth.toString().padLeft(2, '0')}/${expYear! >= 2000 ? expYear! % 100 : expYear}'
        : '';
    return '${brand ?? 'Card'} •••• $last4$exp';
  }
}
