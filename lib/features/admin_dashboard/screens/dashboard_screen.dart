import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants.dart';
import '../../models/models.dart';
import '../providers/admin_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookingsAsync = ref.watch(adminBookingsProvider);
    final trucksAsync = ref.watch(adminActiveTrucksProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          bookingsAsync.when(
            data: (bookings) => _EarningsCards(bookings: bookings),
            loading: () => const _EarningsCards(bookings: []),
            error: (_, __) => const _EarningsCards(bookings: []),
          ),
          const SizedBox(height: 32),
          Text(
            'Live Map – Active Drivers',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 400,
            child: trucksAsync.when(
              data: (trucks) => _LiveMap(trucks: trucks),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}

class _EarningsCards extends StatelessWidget {
  const _EarningsCards({required this.bookings});

  final List<Booking> bookings;

  @override
  Widget build(BuildContext context) {
    final completed = bookings.where((b) => b.status == 'completed').toList();
    final totalRevenue = completed.fold<double>(
      0,
      (sum, b) => sum + (b.price ?? 0),
    );
    final commission = totalRevenue * AppConstants.platformCommissionRate;
    final activeJobs = bookings.where((b) {
      final s = b.status;
      return s != 'completed' && s != 'cancelled';
    }).length;

    return Row(
      children: [
        Expanded(
          child: _StatCard(
            title: 'Total Revenue',
            value: '${totalRevenue.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
            icon: Icons.payments_rounded,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _StatCard(
            title: 'Platform Commission',
            value: '${commission.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
            icon: Icons.account_balance_wallet_rounded,
          ),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: _StatCard(
            title: 'Active Jobs',
            value: '$activeJobs',
            icon: Icons.directions_car_rounded,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  final String title;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    const goldAccent = Color(0xFFD4AF37);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: goldAccent, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Colors.white70,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: goldAccent,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiveMap extends StatelessWidget {
  const _LiveMap({required this.trucks});

  final List<TowTruck> trucks;

  @override
  Widget build(BuildContext context) {
    const defaultCenter = LatLng(41.0082, 28.9784);
    final points = trucks
        .map((t) => LatLng(t.currentLatitude, t.currentLongitude))
        .where((p) => p.latitude != 0 || p.longitude != 0)
        .toList();
    final center = points.isEmpty
        ? defaultCenter
        : LatLng(
            points.map((e) => e.latitude).reduce((a, b) => a + b) / points.length,
            points.map((e) => e.longitude).reduce((a, b) => a + b) / points.length,
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: FlutterMap(
        options: MapOptions(
          initialCenter: center,
          initialZoom: points.isEmpty ? 10 : 12,
          minZoom: 3,
          maxZoom: 18,
        ),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.cekici.cekici',
          ),
          MarkerLayer(
            markers: trucks
                .map(
                  (t) => Marker(
                    point: LatLng(t.currentLatitude, t.currentLongitude),
                    width: 40,
                    height: 40,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.local_shipping_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}
