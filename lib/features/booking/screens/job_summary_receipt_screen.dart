import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:printing/printing.dart';

import '../../../core/constants.dart';
import '../../../models/models.dart';
import '../../../services/receipt_service.dart';
import '../receipt/receipt_pdf.dart';
import '../../auth/providers/auth_state_provider.dart';

/// Job Summary & Receipt screen for the Client App after a completed booking.
class JobSummaryReceiptScreen extends ConsumerStatefulWidget {
  const JobSummaryReceiptScreen({
    super.key,
    required this.bookingId,
  });

  final int bookingId;

  @override
  ConsumerState<JobSummaryReceiptScreen> createState() => _JobSummaryReceiptScreenState();
}

class _JobSummaryReceiptScreenState extends ConsumerState<JobSummaryReceiptScreen> {
  ReceiptData? _data;
  bool _loading = true;
  String? _error;
  bool _sendingEmail = false;
  bool _pdfGenerating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await fetchReceiptData(widget.bookingId);
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
          if (data == null) _error = 'Receipt not found';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _downloadPdf() async {
    final data = _data;
    if (data == null) return;
    setState(() => _pdfGenerating = true);
    try {
      final bytes = await buildReceiptPdf(data);
      if (!mounted) return;
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'Cekici_Receipt_${data.booking.id}',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  Future<void> _emailReceipt() async {
    final data = _data;
    if (data == null) return;
    final user = await ref.read(currentAppUserProvider.future);
    final email = user?.email?.trim();
    if (email == null || email.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Add your email in profile to receive the receipt'),
          ),
        );
      }
      return;
    }
    setState(() => _sendingEmail = true);
    try {
      final ok = await sendReceiptEmail(bookingId: data.booking.id, toEmail: email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(ok ? 'Receipt sent to $email' : 'Failed to send email'),
            backgroundColor: ok ? Colors.green : null,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingEmail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Summary & Receipt')),
        body: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading receipt...'),
            ],
          ),
        ),
      );
    }

    if (_error != null || _data == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Job Summary & Receipt')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, size: 48, color: Theme.of(context).colorScheme.error),
                const SizedBox(height: 16),
                Text(_error ?? 'Not found', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Back'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final data = _data!;
    final b = data.booking;
    final priceStr = b.price != null
        ? '${b.price!.toStringAsFixed(0)} ${AppConstants.currencySymbol}'
        : '—';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Summary & Receipt'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Receipt card
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'RECEIPT #${b.id}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                    ),
                    const SizedBox(height: 16),
                    _receiptRow(context, 'Driver', data.driverName),
                    _receiptRow(context, 'Plate', data.plateNumber),
                    _receiptRow(context, 'Duration', data.formattedDuration),
                    _receiptRow(context, 'Distance', data.formattedDistance),
                    _receiptRow(context, 'Pickup', b.pickupAddress),
                    _receiptRow(context, 'Destination', b.destinationAddress),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        Text(
                          priceStr,
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Map snapshot
            Text(
              'Route',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 160,
                child: FlutterMap(
                  options: MapOptions(
                    initialCenter: LatLng(b.pickupLat, b.pickupLng),
                    initialZoom: 12,
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.none,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.cekici.cekici',
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(b.pickupLat, b.pickupLng),
                          width: 32,
                          height: 32,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 32),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _pdfGenerating ? null : _downloadPdf,
              icon: _pdfGenerating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf),
              label: Text(_pdfGenerating ? 'Preparing PDF...' : 'Download PDF'),
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _sendingEmail ? null : _emailReceipt,
              icon: _sendingEmail
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.email_outlined),
              label: Text(_sendingEmail ? 'Sending...' : 'Email me receipt'),
              style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
            ),
            const SizedBox(height: 32),
            Text(
              'This is a digital summary. Your official e-invoice will be sent to your registered email within 24 hours.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                    fontStyle: FontStyle.italic,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _receiptRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
