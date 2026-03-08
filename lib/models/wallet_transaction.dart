/// Single wallet transaction (credit or debit).
class WalletTransaction {
  const WalletTransaction({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    required this.status,
    this.referenceId,
    this.description,
    this.createdAt,
  });

  final int id;
  final int walletId;
  /// Positive = credit (e.g. booking_credit), negative = debit (withdrawal).
  final double amount;
  final String type; // booking_credit, tip, withdrawal, withdrawal_fee, adjustment
  final String status; // completed, pending_admin_approval, rejected, cancelled
  final int? referenceId;
  final String? description;
  final DateTime? createdAt;

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
  bool get isPending => status == 'pending_admin_approval';

  factory WalletTransaction.fromJson(Map<String, dynamic> json) =>
      WalletTransaction(
        id: json['id'] as int,
        walletId: json['wallet_id'] as int,
        amount: (json['amount'] as num).toDouble(),
        type: json['type'] as String,
        status: json['status'] as String? ?? 'completed',
        referenceId: json['reference_id'] as int?,
        description: json['description'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'wallet_id': walletId,
        'amount': amount,
        'type': type,
        'status': status,
        if (referenceId != null) 'reference_id': referenceId,
        if (description != null) 'description': description,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      };
}
