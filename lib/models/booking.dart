/// Booking model matching PostgreSQL bookings table.
class Booking {
  const Booking({
    required this.id,
    required this.clientId,
    this.driverId,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.pickupLat,
    required this.pickupLng,
    this.price,
    required this.vehicleTypeRequested,
    this.status = 'pending',
    this.damagePhotos,
    this.deliverySignatureUrl,
    this.paymentId,
    this.endedAt,
    this.createdAt,
    this.updatedAt,
    this.isIntercity = false,
    this.desiredPickupAt,
    this.estimatedTolls,
    this.destinationLat,
    this.destinationLng,
    this.vehicleValueTier,
    this.isSurgePricing = false,
    this.driverNetAmount,
    this.platformCommissionPercent,
    this.cancelledBy,
    this.cancelledAt,
    this.acceptedAt,
    this.estimatedArrivalAt,
    this.driverStartedAt,
    this.isPriorityRematch = false,
  });

  final int id;
  final int clientId;
  final int? driverId;
  final String pickupAddress;
  final String destinationAddress;
  final double pickupLat;
  final double pickupLng;
  final double? price;
  final String vehicleTypeRequested; // 'standard' | 'heavy' | 'motorcycle'
  final String status; // 'pending' | 'accepted' | 'on_the_way' | 'picked_up' | 'completed' | 'cancelled'
  /// Pre-pickup damage photo URLs (4 required for proof of work).
  final List<String>? damagePhotos;
  /// Customer signature image URL at delivery.
  final String? deliverySignatureUrl;
  /// Pre-auth payment/intent id from gateway; capture when job is completed.
  final String? paymentId;
  /// When the job was completed (delivery confirmed).
  final DateTime? endedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// True when pickup and destination are in different cities / long distance.
  final bool isIntercity;
  /// For intercity: preferred pickup date/time (planned transfer).
  final DateTime? desiredPickupAt;
  /// Estimated highway/bridge tolls included in price.
  final double? estimatedTolls;
  final double? destinationLat;
  final double? destinationLng;
  /// low, medium, high. High value restricts job to Gold drivers only.
  final String? vehicleValueTier;
  /// When true, platform commission is reduced by 5% for this booking.
  final bool isSurgePricing;
  /// Net amount sent to driver (set at completion).
  final double? driverNetAmount;
  /// Platform commission % applied (set at completion).
  final double? platformCommissionPercent;
  /// Who cancelled: 'client' or 'driver'.
  final String? cancelledBy;
  final DateTime? cancelledAt;
  /// When the driver accepted the booking.
  final DateTime? acceptedAt;
  /// Estimated arrival at pickup (for penalty: 50% through time).
  final DateTime? estimatedArrivalAt;
  /// When driver status became on_the_way.
  final DateTime? driverStartedAt;
  /// True when re-opened after driver cancel; high priority for other drivers.
  final bool isPriorityRematch;

  factory Booking.fromJson(Map<String, dynamic> json) {
    final damagePhotosRaw = json['damage_photos'];
    List<String>? damagePhotos;
    if (damagePhotosRaw is List) {
      damagePhotos = damagePhotosRaw.map((e) => e.toString()).toList();
    }
    return Booking(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      driverId: json['driver_id'] as int?,
      pickupAddress: json['pickup_address'] as String,
      destinationAddress: json['destination_address'] as String,
      pickupLat: (json['pickup_lat'] as num).toDouble(),
      pickupLng: (json['pickup_lng'] as num).toDouble(),
      price: (json['price'] as num?)?.toDouble(),
      vehicleTypeRequested: json['vehicle_type_requested'] as String,
      status: json['status'] as String? ?? 'pending',
      damagePhotos: damagePhotos,
      deliverySignatureUrl: json['delivery_signature_url'] as String?,
      paymentId: json['payment_id'] as String?,
      endedAt: json['ended_at'] != null
          ? DateTime.parse(json['ended_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      isIntercity: json['is_intercity'] as bool? ?? false,
      desiredPickupAt: json['desired_pickup_at'] != null
          ? DateTime.parse(json['desired_pickup_at'] as String)
          : null,
      estimatedTolls: (json['estimated_tolls'] as num?)?.toDouble(),
      destinationLat: (json['destination_lat'] as num?)?.toDouble(),
      destinationLng: (json['destination_lng'] as num?)?.toDouble(),
      vehicleValueTier: json['vehicle_value_tier'] as String?,
      isSurgePricing: json['is_surge_pricing'] as bool? ?? false,
      driverNetAmount: (json['driver_net_amount'] as num?)?.toDouble(),
      platformCommissionPercent: (json['platform_commission_percent'] as num?)?.toDouble(),
      cancelledBy: json['cancelled_by'] as String?,
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
      acceptedAt: json['accepted_at'] != null ? DateTime.parse(json['accepted_at'] as String) : null,
      estimatedArrivalAt: json['estimated_arrival_at'] != null ? DateTime.parse(json['estimated_arrival_at'] as String) : null,
      driverStartedAt: json['driver_started_at'] != null ? DateTime.parse(json['driver_started_at'] as String) : null,
      isPriorityRematch: json['is_priority_rematch'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'client_id': clientId,
        if (driverId != null) 'driver_id': driverId,
        'pickup_address': pickupAddress,
        'destination_address': destinationAddress,
        'pickup_lat': pickupLat,
        'pickup_lng': pickupLng,
        if (price != null) 'price': price,
        'vehicle_type_requested': vehicleTypeRequested,
        'status': status,
        if (damagePhotos != null) 'damage_photos': damagePhotos,
        if (deliverySignatureUrl != null) 'delivery_signature_url': deliverySignatureUrl,
        if (paymentId != null) 'payment_id': paymentId,
        if (endedAt != null) 'ended_at': endedAt!.toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
        'is_intercity': isIntercity,
        if (desiredPickupAt != null) 'desired_pickup_at': desiredPickupAt!.toIso8601String(),
        if (estimatedTolls != null) 'estimated_tolls': estimatedTolls,
        if (destinationLat != null) 'destination_lat': destinationLat,
        if (destinationLng != null) 'destination_lng': destinationLng,
        if (vehicleValueTier != null) 'vehicle_value_tier': vehicleValueTier,
        'is_surge_pricing': isSurgePricing,
        if (driverNetAmount != null) 'driver_net_amount': driverNetAmount,
        if (platformCommissionPercent != null) 'platform_commission_percent': platformCommissionPercent,
        if (cancelledBy != null) 'cancelled_by': cancelledBy,
        if (cancelledAt != null) 'cancelled_at': cancelledAt!.toIso8601String(),
        if (acceptedAt != null) 'accepted_at': acceptedAt!.toIso8601String(),
        if (estimatedArrivalAt != null) 'estimated_arrival_at': estimatedArrivalAt!.toIso8601String(),
        if (driverStartedAt != null) 'driver_started_at': driverStartedAt!.toIso8601String(),
        'is_priority_rematch': isPriorityRematch,
      };

  Booking copyWith({
    int? id,
    int? clientId,
    int? driverId,
    String? pickupAddress,
    String? destinationAddress,
    double? pickupLat,
    double? pickupLng,
    double? price,
    String? vehicleTypeRequested,
    String? status,
    List<String>? damagePhotos,
    String? deliverySignatureUrl,
    String? paymentId,
    DateTime? endedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isIntercity,
    DateTime? desiredPickupAt,
    double? estimatedTolls,
    double? destinationLat,
    double? destinationLng,
    String? vehicleValueTier,
    bool? isSurgePricing,
    double? driverNetAmount,
    double? platformCommissionPercent,
    String? cancelledBy,
    DateTime? cancelledAt,
    DateTime? acceptedAt,
    DateTime? estimatedArrivalAt,
    DateTime? driverStartedAt,
    bool? isPriorityRematch,
  }) =>
      Booking(
        id: id ?? this.id,
        clientId: clientId ?? this.clientId,
        driverId: driverId ?? this.driverId,
        pickupAddress: pickupAddress ?? this.pickupAddress,
        destinationAddress: destinationAddress ?? this.destinationAddress,
        pickupLat: pickupLat ?? this.pickupLat,
        pickupLng: pickupLng ?? this.pickupLng,
        price: price ?? this.price,
        vehicleTypeRequested:
            vehicleTypeRequested ?? this.vehicleTypeRequested,
        status: status ?? this.status,
        damagePhotos: damagePhotos ?? this.damagePhotos,
        deliverySignatureUrl: deliverySignatureUrl ?? this.deliverySignatureUrl,
        paymentId: paymentId ?? this.paymentId,
        endedAt: endedAt ?? this.endedAt,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        isIntercity: isIntercity ?? this.isIntercity,
        desiredPickupAt: desiredPickupAt ?? this.desiredPickupAt,
        estimatedTolls: estimatedTolls ?? this.estimatedTolls,
        destinationLat: destinationLat ?? this.destinationLat,
        destinationLng: destinationLng ?? this.destinationLng,
        vehicleValueTier: vehicleValueTier ?? this.vehicleValueTier,
        isSurgePricing: isSurgePricing ?? this.isSurgePricing,
        driverNetAmount: driverNetAmount ?? this.driverNetAmount,
        platformCommissionPercent: platformCommissionPercent ?? this.platformCommissionPercent,
        cancelledBy: cancelledBy ?? this.cancelledBy,
        cancelledAt: cancelledAt ?? this.cancelledAt,
        acceptedAt: acceptedAt ?? this.acceptedAt,
        estimatedArrivalAt: estimatedArrivalAt ?? this.estimatedArrivalAt,
        driverStartedAt: driverStartedAt ?? this.driverStartedAt,
        isPriorityRematch: isPriorityRematch ?? this.isPriorityRematch,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Booking &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          clientId == other.clientId;

  @override
  int get hashCode => Object.hash(id, clientId);

  @override
  String toString() =>
      'Booking(id: $id, status: $status, pickupAddress: $pickupAddress)';
}
