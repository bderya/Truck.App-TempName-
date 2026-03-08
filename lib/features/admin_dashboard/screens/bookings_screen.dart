import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../providers/admin_providers.dart';

class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(adminBookingsProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: bookingsAsync.when(
        data: (bookings) => Card(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              columns: const [
                DataColumn(label: Text('ID')),
                DataColumn(label: Text('Pickup')),
                DataColumn(label: Text('Destination')),
                DataColumn(label: Text('Type')),
                DataColumn(label: Text('Status')),
                DataColumn(label: Text('Price')),
                DataColumn(label: Text('Created')),
              ],
              rows: bookings.map((b) {
                return DataRow(
                  cells: [
                    DataCell(Text('${b.id}')),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(b.pickupAddress, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 180),
                      child: Text(b.destinationAddress, overflow: TextOverflow.ellipsis),
                    )),
                    DataCell(Text(b.vehicleTypeRequested)),
                    DataCell(Text(b.status)),
                    DataCell(Text(b.price != null ? '${b.price!.toStringAsFixed(0)} ${AppConstants.currencySymbol}' : '–')),
                    DataCell(Text(b.createdAt?.toIso8601String().substring(0, 19) ?? '–')),
                  ],
                );
              }).toList(),
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
