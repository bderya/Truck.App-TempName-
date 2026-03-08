import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/constants.dart';
import '../../../models/models.dart';

/// Builds a professional invoice-style PDF for the job receipt.
Future<Uint8List> buildReceiptPdf(ReceiptData data) async {
  final pdf = pw.Document();
  pw.ImageProvider? logoImage;
  try {
    final bytes = await rootBundle.load('assets/images/logo.png');
    logoImage = pw.MemoryImage(
      bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
    );
  } catch (_) {}

  final b = data.booking;
  final priceStr = b.price != null
      ? '${b.price!.toStringAsFixed(0)} ${AppConstants.currencySymbol}'
      : '—';

  pdf.addPage(
    pw.Page(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(32),
      build: (pw.Context context) {
        return pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                if (logoImage != null)
                  pw.Image(logoImage, width: 120, height: 40, fit: pw.BoxFit.contain)
                else
                  pw.Text(
                    AppConstants.appName,
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                pw.Text(
                  'RECEIPT #${b.id}',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),
            pw.Divider(thickness: 2),
            pw.SizedBox(height: 20),
            pw.Text(
              'Job Summary',
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 16),
            _row('Date', b.endedAt != null
                ? '${b.endedAt!.day.toString().padLeft(2, '0')}/${b.endedAt!.month.toString().padLeft(2, '0')}/${b.endedAt!.year}'
                : '—'),
            _row('Driver', data.driverName),
            _row('Plate', data.plateNumber),
            _row('Duration', data.formattedDuration),
            _row('Distance', data.formattedDistance),
            _row('Vehicle type', b.vehicleTypeRequested),
            pw.SizedBox(height: 12),
            _row('Pickup', b.pickupAddress),
            _row('Destination', b.destinationAddress),
            pw.SizedBox(height: 20),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Total',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  priceStr,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ],
            ),
            pw.SizedBox(height: 60),
            pw.Divider(),
            pw.SizedBox(height: 8),
            pw.Text(
              'This is a digital summary. Your official e-invoice will be sent to your registered email within 24 hours.',
              style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
              textAlign: pw.TextAlign.center,
            ),
          ],
        );
      },
    ),
  );

  return pdf.save();
}

pw.Widget _row(String label, String value) {
  return pw.Padding(
    padding: const pw.EdgeInsets.only(bottom: 6),
    child: pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(
          width: 100,
          child: pw.Text(
            label,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
        ),
        pw.Expanded(
          child: pw.Text(value, style: const pw.TextStyle(fontSize: 10)),
        ),
      ],
    ),
  );
}
