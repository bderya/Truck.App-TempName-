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
