import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../core/constants.dart';
import '../../../models/models.dart';

/// Overlay shown when a new pending booking is detected (Supabase Realtime or Socket.io).
/// Includes 30s countdown, estimated earning, pickup distance, vehicle info, and alert sound.
class JobRequestOverlay extends StatefulWidget {
  const JobRequestOverlay({
    super.key,
    required this.booking,
    required this.pickupDistanceKm,
    required this.onAccept,
    required this.onDecline,
    this.countdownSeconds = 30,
  });

  final Booking booking;
  final double pickupDistanceKm;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final int countdownSeconds;

  @override
  State<JobRequestOverlay> createState() => _JobRequestOverlayState();
}

class _JobRequestOverlayState extends State<JobRequestOverlay> {
  late int _remainingSeconds;
  Timer? _timer;
  AudioPlayer? _audioPlayer;
  bool _actionTaken = false;

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
  void initState() {
    super.initState();
    _remainingSeconds = widget.countdownSeconds;
    _startCountdown();
    _playAlertSound();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted || _actionTaken) return;
      setState(() {
        _remainingSeconds--;
        if (_remainingSeconds <= 0) {
          _timer?.cancel();
          _stopSound();
          widget.onDecline();
        }
      });
    });
  }

  Future<void> _playAlertSound() async {
    try {
      _audioPlayer = AudioPlayer();
      await _audioPlayer!.setReleaseMode(ReleaseMode.loop);
      await _audioPlayer!.setSource(AssetSource('sounds/alert.mp3'));
      await _audioPlayer!.resume();
    } catch (_) {
      // Asset missing or play failed; overlay still works
    }
  }

  Future<void> _stopSound() async {
    try {
      await _audioPlayer?.stop();
      await _audioPlayer?.dispose();
    } catch (_) {}
    _audioPlayer = null;
  }

  void _onAccept() {
    if (_actionTaken) return;
    _actionTaken = true;
    _timer?.cancel();
    _stopSound();
    widget.onAccept();
  }

  void _onDecline() {
    if (_actionTaken) return;
    _actionTaken = true;
    _timer?.cancel();
    _stopSound();
    widget.onDecline();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _stopSound();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final price = widget.booking.price;
    final priceStr = price != null
        ? '${price.toStringAsFixed(0)} ${AppConstants.currencySymbol}'
        : 'TBD';

    return Material(
      color: Colors.black54,
      child: SizedBox.expand(
        child: SafeArea(
          child: Center(
            child: Padding(
            padding: const EdgeInsets.all(24),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(20),
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'New Job Request',
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        ),
                        if (widget.booking.isIntercity)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.tertiaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Intercity',
                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: Theme.of(context).colorScheme.onTertiaryContainer,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(
                          width: 72,
                          height: 72,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 72,
                                height: 72,
                                child: CircularProgressIndicator(
                                  value: _remainingSeconds / widget.countdownSeconds,
                                  strokeWidth: 6,
                                  backgroundColor: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    _remainingSeconds <= 10
                                        ? Theme.of(context).colorScheme.error
                                        : Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                              Text(
                                '$_remainingSeconds',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Estimated Earning',
                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                priceStr,
                                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green.shade700,
                                    ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Icon(
                                    Icons.location_on,
                                    size: 18,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    '${widget.pickupDistanceKm.toStringAsFixed(1)} km away',
                                    style: Theme.of(context).textTheme.titleSmall,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.directions_car_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Customer vehicle',
                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface
                                          .withValues(alpha: 0.7),
                                    ),
                              ),
                              Text(
                                _vehicleTypeLabel(widget.booking.vehicleTypeRequested),
                                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    _InfoRow(
                      icon: Icons.location_on,
                      label: 'Pickup',
                      value: widget.booking.pickupAddress,
                    ),
                    const SizedBox(height: 6),
                    _InfoRow(
                      icon: Icons.flag,
                      label: 'Destination',
                      value: widget.booking.destinationAddress,
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: _onDecline,
                            icon: const Icon(Icons.close),
                            label: const Text('Decline'),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Theme.of(context).colorScheme.error,
                              side: BorderSide(
                                color: Theme.of(context).colorScheme.error,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: _onAccept,
                            icon: const Icon(Icons.check),
                            label: const Text('Accept'),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: 0.6),
                    ),
              ),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
