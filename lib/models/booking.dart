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
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Booking.fromJson(Map<String, dynamic> json) => Booking(
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
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'] as String)
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'] as String)
            : null,
      );

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
