/// User model matching PostgreSQL users table.
class User {
  const User({
    required this.id,
    required this.phoneNumber,
    required this.fullName,
    required this.userType,
    this.avatarUrl,
    this.email,
    this.defaultCardTokenId,
    this.isVerified = false,
    this.status = 'pending',
    this.licenseImageUrl,
    this.criminalRecordUrl,
    this.nationalId,
    this.selfieWithLicenseUrl,
    this.iban,
    this.legalEntityTaxId,
    this.averageRating,
    this.isUnderReview = false,
    this.isActive = true,
    this.suspendedUntil,
    this.consentVersion,
    this.consentDate,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final String phoneNumber;
  final String fullName;
  final String userType; // 'client' | 'driver'
  final String? avatarUrl;
  final String? email;
  final String? defaultCardTokenId;
  final bool isVerified;
  final String status; // 'pending' | 'approved' | 'rejected'
  final String? licenseImageUrl;
  final String? criminalRecordUrl;
  final String? nationalId;
  final String? selfieWithLicenseUrl;
  final String? iban;
  final String? legalEntityTaxId;
  /// Driver: average of client ratings. Below 3.5 triggers review.
  final double? averageRating;
  /// Driver: true when average_rating < 3.5; hidden from map and dispatch.
  final bool isUnderReview;
  /// Driver: false when suspended (e.g. 3 cancels in 7 days).
  final bool isActive;
  /// When suspension ends (48h after 3rd cancel).
  final DateTime? suspendedUntil;
  /// Version of accepted terms (e.g. v1.0).
  final String? consentVersion;
  /// When the user accepted the terms.
  final DateTime? consentDate;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as int,
        phoneNumber: json['phone_number'] as String,
        fullName: json['full_name'] as String,
        userType: json['user_type'] as String,
        avatarUrl: json['avatar_url'] as String?,
        email: json['email'] as String?,
        defaultCardTokenId: json['default_card_token_id'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        status: json['status'] as String? ?? 'pending',
        licenseImageUrl: json['license_image_url'] as String?,
        criminalRecordUrl: json['criminal_record_url'] as String?,
        nationalId: json['national_id'] as String?,
        selfieWithLicenseUrl: json['selfie_with_license_url'] as String?,
        iban: json['iban'] as String?,
        legalEntityTaxId: json['legal_entity_tax_id'] as String?,
        averageRating: (json['average_rating'] as num?)?.toDouble(),
        isUnderReview: json['is_under_review'] as bool? ?? false,
        isActive: json['is_active'] as bool? ?? true,
        suspendedUntil: json['suspended_until'] != null ? DateTime.parse(json['suspended_until'] as String) : null,
        consentVersion: json['consent_version'] as String?,
        consentDate: json['consent_date'] != null ? DateTime.parse(json['consent_date'] as String) : null,
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
        if (email != null) 'email': email,
        if (defaultCardTokenId != null) 'default_card_token_id': defaultCardTokenId,
        'is_verified': isVerified,
        'status': status,
        if (licenseImageUrl != null) 'license_image_url': licenseImageUrl,
        if (criminalRecordUrl != null) 'criminal_record_url': criminalRecordUrl,
        if (nationalId != null) 'national_id': nationalId,
        if (selfieWithLicenseUrl != null) 'selfie_with_license_url': selfieWithLicenseUrl,
        if (iban != null) 'iban': iban,
        if (legalEntityTaxId != null) 'legal_entity_tax_id': legalEntityTaxId,
        if (averageRating != null) 'average_rating': averageRating,
        'is_under_review': isUnderReview,
        'is_active': isActive,
        if (suspendedUntil != null) 'suspended_until': suspendedUntil!.toIso8601String(),
        if (consentVersion != null) 'consent_version': consentVersion,
        if (consentDate != null) 'consent_date': consentDate!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  User copyWith({
    int? id,
    String? phoneNumber,
    String? fullName,
    String? userType,
    String? avatarUrl,
    String? email,
    String? defaultCardTokenId,
    bool? isVerified,
    String? status,
    String? licenseImageUrl,
    String? criminalRecordUrl,
    String? nationalId,
    String? selfieWithLicenseUrl,
    String? iban,
    String? legalEntityTaxId,
    double? averageRating,
    bool? isUnderReview,
    bool? isActive,
    DateTime? suspendedUntil,
    String? consentVersion,
    DateTime? consentDate,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      User(
        id: id ?? this.id,
        phoneNumber: phoneNumber ?? this.phoneNumber,
        fullName: fullName ?? this.fullName,
        userType: userType ?? this.userType,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        email: email ?? this.email,
        defaultCardTokenId: defaultCardTokenId ?? this.defaultCardTokenId,
        isVerified: isVerified ?? this.isVerified,
        status: status ?? this.status,
        licenseImageUrl: licenseImageUrl ?? this.licenseImageUrl,
        criminalRecordUrl: criminalRecordUrl ?? this.criminalRecordUrl,
        nationalId: nationalId ?? this.nationalId,
        selfieWithLicenseUrl: selfieWithLicenseUrl ?? this.selfieWithLicenseUrl,
        iban: iban ?? this.iban,
        legalEntityTaxId: legalEntityTaxId ?? this.legalEntityTaxId,
        averageRating: averageRating ?? this.averageRating,
        isUnderReview: isUnderReview ?? this.isUnderReview,
        isActive: isActive ?? this.isActive,
        suspendedUntil: suspendedUntil ?? this.suspendedUntil,
        consentVersion: consentVersion ?? this.consentVersion,
        consentDate: consentDate ?? this.consentDate,
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
