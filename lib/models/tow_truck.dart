import 'package:latlong2/latlong.dart';

List<String>? _parseStringList(dynamic v) {
  if (v == null) return null;
  if (v is List) return v.map((e) => e.toString()).toList();
  return null;
}

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
    this.plateImageUrl,
    this.towTruckStyle,
    this.maxWeightCapacityKg,
    this.openToIntercity = false,
    this.vehicleModelYear,
    this.tierCategory,
    this.qualityScore,
    this.isInspected = true,
    this.lastInspectionAt,
    this.inspectionPhotoUrls,
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
  final String? plateImageUrl;
  final String? towTruckStyle;
  final int? maxWeightCapacityKg;
  final bool openToIntercity;
  final int? vehicleModelYear;
  final String? tierCategory; // Gold, Silver, Bronze
  final double? qualityScore;
  final bool isInspected;
  final DateTime? lastInspectionAt;
  final List<String>? inspectionPhotoUrls;
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
        plateImageUrl: json['plate_image_url'] as String?,
        towTruckStyle: json['tow_truck_style'] as String?,
        maxWeightCapacityKg: json['max_weight_capacity_kg'] as int?,
        openToIntercity: json['open_to_intercity'] as bool? ?? false,
        vehicleModelYear: json['vehicle_model_year'] as int?,
        tierCategory: json['tier_category'] as String?,
        qualityScore: (json['quality_score'] as num?)?.toDouble(),
        isInspected: json['is_inspected'] as bool? ?? true,
        lastInspectionAt: json['last_inspection_at'] != null
            ? DateTime.parse(json['last_inspection_at'] as String)
            : null,
        inspectionPhotoUrls: _parseStringList(json['inspection_photo_urls']),
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
        if (plateImageUrl != null) 'plate_image_url': plateImageUrl,
        if (towTruckStyle != null) 'tow_truck_style': towTruckStyle,
        if (maxWeightCapacityKg != null) 'max_weight_capacity_kg': maxWeightCapacityKg,
        'open_to_intercity': openToIntercity,
        if (vehicleModelYear != null) 'vehicle_model_year': vehicleModelYear,
        if (tierCategory != null) 'tier_category': tierCategory,
        if (qualityScore != null) 'quality_score': qualityScore,
        'is_inspected': isInspected,
        if (lastInspectionAt != null) 'last_inspection_at': lastInspectionAt!.toIso8601String(),
        if (inspectionPhotoUrls != null) 'inspection_photo_urls': inspectionPhotoUrls,
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
    String? plateImageUrl,
    String? towTruckStyle,
    int? maxWeightCapacityKg,
    bool? openToIntercity,
    int? vehicleModelYear,
    String? tierCategory,
    double? qualityScore,
    bool? isInspected,
    DateTime? lastInspectionAt,
    List<String>? inspectionPhotoUrls,
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
        plateImageUrl: plateImageUrl ?? this.plateImageUrl,
        towTruckStyle: towTruckStyle ?? this.towTruckStyle,
        maxWeightCapacityKg: maxWeightCapacityKg ?? this.maxWeightCapacityKg,
        openToIntercity: openToIntercity ?? this.openToIntercity,
        vehicleModelYear: vehicleModelYear ?? this.vehicleModelYear,
        tierCategory: tierCategory ?? this.tierCategory,
        qualityScore: qualityScore ?? this.qualityScore,
        isInspected: isInspected ?? this.isInspected,
        lastInspectionAt: lastInspectionAt ?? this.lastInspectionAt,
        inspectionPhotoUrls: inspectionPhotoUrls ?? this.inspectionPhotoUrls,
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
