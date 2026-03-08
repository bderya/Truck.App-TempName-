import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../models/models.dart';
import 'providers/driver_booking_provider.dart';
import 'providers/driver_earnings_provider.dart';

/// Driver Wallet & Earnings Report: dashboard cards, weekly chart, transaction list, date filter.
class DriverWalletScreen extends ConsumerWidget {
  const DriverWalletScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(todayEarningsProvider);
    final weekAsync = ref.watch(weekEarningsProvider);
    final filter = ref.watch(earningsFilterProvider);
    final bookingsAsync = ref.watch(driverEarningsBookingsProvider);
    final trendAsync = ref.watch(weeklyTrendProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Earnings'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          final driverId = ref.read(driverIdProvider);
          if (driverId != null) {
            ref.invalidate(driverCompletedBookingsProvider(driverId));
          }
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Row(
              children: [
                Expanded(
                  child: _EarningsCard(
                    title: "Today's Earnings",
                    asyncValue: todayAsync,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _EarningsCard(
                    title: "This Week's Total",
                    asyncValue: weekAsync,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Filter by',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            SegmentedButton<EarningsFilter>(
              segments: const [
                ButtonSegment(value: EarningsFilter.day, label: Text('Day'), icon: Icon(Icons.today)),
                ButtonSegment(value: EarningsFilter.week, label: Text('Week'), icon: Icon(Icons.date_range)),
                ButtonSegment(value: EarningsFilter.month, label: Text('Month'), icon: Icon(Icons.calendar_month)),
              ],
              selected: {filter},
              onSelectionChanged: (s) => ref.read(earningsFilterProvider.notifier).state = s.first,
            ),
            const SizedBox(height: 24),
            Text(
              'Weekly trend',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: trendAsync.when(
                data: (values) => _WeeklyBarChart(values: values),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Could not load chart')),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Transactions',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 8),
            bookingsAsync.when(
              data: (bookings) => bookings.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No completed jobs in this period',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: bookings.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final b = bookings[i];
                        return _TransactionTile(booking: b);
                      },
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Error: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EarningsCard extends StatelessWidget {
  const _EarningsCard({
    required this.title,
    required this.asyncValue,
  });

  final String title;
  final AsyncValue<double> asyncValue;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 8),
            asyncValue.when(
              data: (value) => Text(
                '${value.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              loading: () => const SizedBox(
                height: 32,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ),
              error: (_, __) => Text(
                '—',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeeklyBarChart extends StatelessWidget {
  const _WeeklyBarChart({required this.values});

  final List<double> values;

  static const _weekdayLabels = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    final maxY = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 1.0 : maxY * 1.2;
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        maxY: top,
        barTouchData: BarTouchData(enabled: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < values.length) {
                  final day = todayStart.subtract(Duration(days: 6 - i));
                  final label = _weekdayLabels[day.weekday - 1];
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '$label ${day.day}',
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 32,
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                if (value <= 0) return const SizedBox.shrink();
                return Text(
                  value.toInt().toString(),
                  style: Theme.of(context).textTheme.labelSmall,
                );
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(show: false),
        barGroups: [
          for (var i = 0; i < values.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: values[i],
                  width: 16,
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                ),
              ],
              showingTooltipIndicators: [],
            ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

String _formatDate(DateTime d) {
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final m = d.month >= 1 && d.month <= 12 ? months[d.month - 1] : '';
  final h = d.hour.toString().padLeft(2, '0');
  final min = d.minute.toString().padLeft(2, '0');
  return '${d.day} $m, $h:$min';
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.booking});

  final Booking booking;

  @override
  Widget build(BuildContext context) {
    final date = booking.endedAt ?? booking.createdAt;
    final dateStr = date != null
        ? _formatDate(date.isUtc ? date.toLocal() : date)
        : '—';
    final net = netPayout(booking);

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0),
      title: Text(
        booking.pickupAddress,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        dateStr,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
      ),
      trailing: Text(
        '${net.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.green.shade700,
            ),
      ),
    );
  }
}
