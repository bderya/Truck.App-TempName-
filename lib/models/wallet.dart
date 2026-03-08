/// Driver wallet: available balance and total earned.
class Wallet {
  const Wallet({
    required this.id,
    required this.driverId,
    required this.availableBalance,
    required this.totalEarned,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int driverId;
  final double availableBalance;
  final double totalEarned;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Wallet.fromJson(Map<String, dynamic> json) => Wallet(
        id: json['id'] as int,
        driverId: json['driver_id'] as int,
        availableBalance: (json['available_balance'] as num).toDouble(),
        totalEarned: (json['total_earned'] as num).toDouble(),
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'driver_id': driverId,
        'available_balance': availableBalance,
        'total_earned': totalEarned,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };
}
