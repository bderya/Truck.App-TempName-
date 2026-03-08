/// User model matching PostgreSQL users table.
class User {
  const User({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.userType,
    this.avatarUrl,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String phoneNumber;
  final String fullName;
  final String userType; // 'client' | 'driver'
  final String? avatarUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        phoneNumber: json['phone_number'] as String,
        fullName: json['full_name'] as String,
        userType: json['user_type'] as String,
        avatarUrl: json['avatar_url'] as String?,
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'phone_number': phoneNumber,
        'full_name': fullName,
        'user_type': userType,
        if (avatarUrl != null) 'avatar_url': avatarUrl,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  User copyWith({
    int? id,
    String? phoneNumber,
    String? fullName,
    String? userType,
    String? avatarUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        fullName: fullName ?? this.fullName,
        userType: userType ?? this.userType,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is User &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          phoneNumber == other.phoneNumber &&
          fullName == other.fullName &&
          userType == other.userType &&
          avatarUrl == other.avatarUrl;

  @override
  int get hashCode =>
      Object.hash(id, phoneNumber, fullName, userType, avatarUrl);

  @override
  String toString() =>
      'User(id: $id, phoneNumber: $phoneNumber, fullName: $fullName, userType: $userType)';
}
