import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../../../services/background_geolocation_service.dart';
import '../../../services/external_navigation_service.dart';
import '../../../services/location_service.dart';
import '../widgets/location_permission_rationale_dialog.dart';
import '../../chat/chat_screen.dart';
import 'delivery_signature_screen.dart';
import 'pre_pickup_photo_screen.dart';

/// Navigation view opened after driver accepts a job. Shows pickup on map
/// and option to open in external maps app.
/// When [towTruckId] is set, starts high-frequency location sync to [tow_trucks]
/// so the client can track the driver in real time.
class JobNavigationScreen extends ConsumerStatefulWidget {
  const JobNavigationScreen({
    super.key,
    required this.booking,
    this.towTruckId,
    required this.locationService,
  });

  final Booking booking;
  final int? towTruckId;
  final LocationService locationService;

  @override
  ConsumerState<JobNavigationScreen> createState() => _JobNavigationScreenState();
}

class _JobNavigationScreenState extends ConsumerState<JobNavigationScreen> {
  bool _cancelLoading = false;
  bool _usingBackgroundGeolocation = false;
  @override
  void initState() {
    super.initState();
    final towTruckId = widget.towTruckId;
    if (towTruckId != null) {
      if (useBackgroundGeolocation) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _startTrackingWithPermission(towTruckId));
      } else {
        widget.locationService.startHighFrequencyLocationSync(
          towTruckId: towTruckId,
        );
      }
    }
  }

  Future<void> _startTrackingWithPermission(int towTruckId) async {
    if (!mounted) return;
    final granted = await requestLocationPermissionWithRationale(context);
    if (!mounted) return;
    if (granted) {
      _usingBackgroundGeolocation = true;
      await ref.read(backgroundGeolocationDriverServiceProvider).start(towTruckId);
    } else {
      widget.locationService.startHighFrequencyLocationSync(towTruckId: towTruckId);
    }
  }

  @override
  void dispose() {
    if (_usingBackgroundGeolocation) {
      ref.read(backgroundGeolocationDriverServiceProvider).stop();
    } else {
      widget.locationService.stopLocationStream();
    }
    super.dispose();
  }

  Future<void> _cancelJob() async {
    final driverId = widget.booking.driverId;
    if (driverId == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('cancel_job'.tr()),
        content: Text('cancel_job_confirm'.tr()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text('no'.tr()),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('yes_cancel'.tr()),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _cancelLoading = true);
    final service = ref.read(driverCancellationServiceProvider);
    final result = await service.cancelBookingByDriver(
      bookingId: widget.booking.id,
      driverId: driverId,
    );
    if (!mounted) return;
    setState(() => _cancelLoading = false);
    if (result.ok) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      String msg = 'İş iptal edildi. Müşteri yeniden eşleştiriliyor.';
      if (result.penaltyApplied) msg += ' 250 ₺ ceza uygulandı.';
      if (result.suspended) msg += ' 7 günde 3 iptal: 48 saat askıya alındınız.';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.error ?? 'cancel_failed'.tr())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final pickup = LatLng(booking.pickupLat, booking.pickupLng);

    return Scaffold(
      appBar: AppBar(
        title: Text('navigate_to_pickup'.tr()),
        actions: [
          if (widget.booking.driverId != null)
            IconButton(
              icon: const Icon(Icons.chat_bubble_outline),
              tooltip: 'Chat',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => ChatScreen(
                    bookingId: widget.booking.id,
                    currentUserId: widget.booking.driverId!,
                  ),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: FlutterMap(
              options: MapOptions(
                initialCenter: pickup,
                initialZoom: 15,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'com.cekici.cekici',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: pickup,
                      width: 48,
                      height: 48,
                      child: const Icon(
                        Icons.location_on,
                        color: Colors.red,
                        size: 48,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.booking.pickupAddress,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${widget.booking.vehicleTypeRequested} • ${widget.booking.price?.toStringAsFixed(0) ?? "—"} ₺',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.7),
                        ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => _startNavigation(),
                    icon: const Icon(Icons.navigation),
                    label: Text('start_navigation'.tr()),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openPrePickupPhotos(context),
                    icon: const Icon(Icons.camera_alt),
                    label: Text('take_pre_pickup_photos'.tr()),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _cancelLoading ? null : _cancelJob,
                    icon: _cancelLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.cancel_outlined, size: 20),
                    label: Text('cancel_job'.tr()),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openPrePickupPhotos(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PrePickupPhotoScreen(
          booking: widget.booking,
          onStartTowing: () {
            Navigator.of(context).pop();
            Navigator.of(context).pushReplacement(
              MaterialPageRoute<void>(
                builder: (_) => DeliverySignatureScreen(
                  booking: widget.booking,
                  onComplete: () => Navigator.of(context).popUntil((route) => route.isFirst),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  void _startNavigation() {
    final target = ExternalNavigationService.getTargetForBooking(widget.booking);
    ExternalNavigationService.showMapPickerAndNavigate(context, target: target);
  }
}
