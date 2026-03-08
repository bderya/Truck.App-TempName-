import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/models.dart';

class BookingBottomSheet extends StatefulWidget {
  const BookingBottomSheet({
    super.key,
    this.userLat,
    this.userLng,
    required this.towTrucks,
    this.onRefresh,
  });

  final double? userLat;
  final double? userLng;
  final List<TowTruck> towTrucks;
  final VoidCallback? onRefresh;

  static const List<String> vehicleTypes = [
    'standard',
    'heavy',
    'motorcycle',
  ];

  static String _vehicleTypeLabel(String type) {
    switch (type) {
      case 'standard':
        return 'Standard';
      case 'heavy':
        return 'Heavy Duty';
      case 'motorcycle':
        return 'Motorcycle';
      default:
        return type;
    }
  }

  @override
  State<BookingBottomSheet> createState() => _BookingBottomSheetState();
}

class _BookingBottomSheetState extends State<BookingBottomSheet> {
  String? _selectedVehicleType;
  double? _distanceKm;
  TowTruck? _nearestTruck;

  @override
  void initState() {
    super.initState();
    _selectedVehicleType = widget.vehicleTypes.first;
    _updateEstimate();
  }

  @override
  void didUpdateWidget(BookingBottomSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.towTrucks != widget.towTrucks ||
        oldWidget.userLat != widget.userLat ||
        oldWidget.userLng != widget.userLng) {
      _updateEstimate();
    }
  }

  void _updateEstimate() {
    if (widget.userLat == null || widget.userLng == null) {
      setState(() {
        _distanceKm = null;
        _nearestTruck = null;
      });
      return;
    }

    final trucksOfType = widget.towTrucks
        .where((t) => t.truckType == _selectedVehicleType)
        .toList();

    if (trucksOfType.isEmpty) {
      setState(() {
        _distanceKm = null;
        _nearestTruck = null;
      });
      return;
    }

    TowTruck? nearest;
    double minDist = double.infinity;

    for (final truck in trucksOfType) {
      final d = truck.distanceFrom(widget.userLat!, widget.userLng!);
      if (d < minDist) {
        minDist = d;
        nearest = truck;
      }
    }

    setState(() {
      _nearestTruck = nearest;
      _distanceKm = minDist / 1000;
    });
  }

  double? get _estimatedPrice {
    if (_selectedVehicleType == null || _distanceKm == null) return null;

    final base = AppConstants.basePriceByVehicleType[_selectedVehicleType] ?? 0;
    final rate = AppConstants.ratePerKmByVehicleType[_selectedVehicleType] ?? 0;

    return base + (_distanceKm! * rate);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.5,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.35,
        maxChildSize: 0.85,
        expand: false,
        builder: (context, scrollController) {
          return ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Request Tow Truck',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 20),
              Text(
                'Vehicle Type',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.7),
                    ),
              ),
              const SizedBox(height: 8),
              ...BookingBottomSheet.vehicleTypes.map((type) {
                final hasTruck = widget.towTrucks
                    .any((t) => t.truckType == type);
                return RadioListTile<String>(
                  value: type,
                  groupValue: _selectedVehicleType,
                  onChanged: hasTruck
                      ? (v) {
                          setState(() {
                            _selectedVehicleType = v;
                            _updateEstimate();
                          });
                        }
                      : null,
                  title: Row(
                    children: [
                      Text(BookingBottomSheet._vehicleTypeLabel(type)),
                      if (!hasTruck)
                        Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            '(none nearby)',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface
                                      .withValues(alpha: 0.5),
                                ),
                          ),
                        ),
                    ],
                  ),
                );
              }),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primaryContainer
                      .withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Estimated Price',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurface
                                .withValues(alpha: 0.8),
                          ),
                    ),
                    const SizedBox(height: 4),
                    if (_estimatedPrice != null) ...[
                      Text(
                        '${_estimatedPrice!.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                      ),
                      if (_distanceKm != null && _nearestTruck != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Base: ${AppConstants.basePriceByVehicleType[_selectedVehicleType]!.toStringAsFixed(0)} ${AppConstants.currencySymbol} '
                          '+ (${_distanceKm!.toStringAsFixed(1)} km × ${AppConstants.ratePerKmByVehicleType[_selectedVehicleType]!.toStringAsFixed(1)} ${AppConstants.currencySymbol}/km)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.7),
                              ),
                        ),
                        Text(
                          'Nearest: ${_nearestTruck!.plateNumber} (~${_distanceKm!.toStringAsFixed(1)} km away)',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withValues(alpha: 0.6),
                              ),
                        ),
                      ],
                    ] else
                      Text(
                        'Select a vehicle type with nearby trucks',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: 0.6),
                            ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _estimatedPrice != null
                      ? () {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Booking request for ${BookingBottomSheet._vehicleTypeLabel(_selectedVehicleType!)} '
                                '— ${_estimatedPrice!.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
                              ),
                            ),
                          );
                        }
                      : null,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Confirm Request'),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
