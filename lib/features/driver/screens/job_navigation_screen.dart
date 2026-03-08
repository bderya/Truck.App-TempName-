import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/models.dart';
import '../../../services/location_service.dart';
import '../../chat/chat_screen.dart';
import 'delivery_signature_screen.dart';
import 'pre_pickup_photo_screen.dart';

/// Navigation view opened after driver accepts a job. Shows pickup on map
/// and option to open in external maps app.
/// When [towTruckId] is set, starts high-frequency location sync to [tow_trucks]
/// so the client can track the driver in real time.
class JobNavigationScreen extends StatefulWidget {
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
  State<JobNavigationScreen> createState() => _JobNavigationScreenState();
}

class _JobNavigationScreenState extends State<JobNavigationScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.towTruckId != null) {
      widget.locationService.startHighFrequencyLocationSync(
        towTruckId: widget.towTruckId!,
      );
    }
  }

  @override
  void dispose() {
    widget.locationService.stopLocationStream();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final booking = widget.booking;
    final pickup = LatLng(booking.pickupLat, booking.pickupLng);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Navigate to pickup'),
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
                    onPressed: () => _openInMaps(widget.booking.pickupLat, widget.booking.pickupLng),
                    icon: const Icon(Icons.navigation),
                    label: const Text('Open in Maps'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _openPrePickupPhotos(context),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take pre-pickup photos'),
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

  Future<void> _openInMaps(double lat, double lng) async {
    final url = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }
}
