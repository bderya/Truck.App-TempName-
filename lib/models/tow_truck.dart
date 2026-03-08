import 'package:latlong2/latlong.dart';

/// Tow truck model matching PostgreSQL tow_trucks table.
class TowTruck {
  const TowTruck({
    required this.id,
    required this.driverId,
    required this.plateNumber,
    required this.truckType,
    required this.currentLatitude,
    required this.currentLongitude,
    this.isAvailable = true,
    this.createdAt,
    this.updatedAt,
  });

  final int id;
  final int driverId;
  final String plateNumber;
  final String truckType; // 'standard' | 'heavy' | 'motorcycle'
  final double currentLatitude;
  final double currentLongitude;
  final bool isAvailable;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory TowTruck.fromJson(Map<String, dynamic> json) => TowTruck(
        id: json['id'] as int,
        driverId: json['driver_id'] as int,
        plateNumber: json['plate_number'] as String,
        truckType: json['truck_type'] as String,
        currentLatitude: (json['current_latitude'] as num).toDouble(),
        currentLongitude: (json['current_longitude'] as num).toDouble(),
        isAvailable: json['is_available'] as bool? ?? true,
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
        'plate_number': plateNumber,
        'truck_type': truckType,
        'current_latitude': currentLatitude,
        'current_longitude': currentLongitude,
        'is_available': isAvailable,
        if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
        if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
      };

  /// Returns distance in meters from this tow truck to the given point.
  /// Uses Vincenty formula (via latlong2) for accuracy.
  double distanceFrom(double latitude, double longitude) {
    const distance = Distance();
    return distance(
      LatLng(currentLatitude, currentLongitude),
      LatLng(latitude, longitude),
    );
  }

  TowTruck copyWith({
    int? id,
    int? driverId,
    String? plateNumber,
    String? truckType,
    double? currentLatitude,
    double? currentLongitude,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      TowTruck(
        id: id ?? this.id,
        driverId: driverId ?? this.driverId,
        plateNumber: plateNumber ?? this.plateNumber,
        truckType: truckType ?? this.truckType,
        currentLatitude: currentLatitude ?? this.currentLatitude,
        currentLongitude: currentLongitude ?? this.currentLongitude,
        isAvailable: isAvailable ?? this.isAvailable,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TowTruck &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          driverId == other.driverId &&
          plateNumber == other.plateNumber;

  @override
  int get hashCode => Object.hash(id, driverId, plateNumber);

  @override
  String toString() =>
      'TowTruck(id: $id, plateNumber: $plateNumber, truckType: $truckType, isAvailable: $isAvailable)';
}
