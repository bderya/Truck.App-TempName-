import 'package:easy_localization/easy_localization.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../models/models.dart';
import 'providers/driver_booking_provider.dart';
import 'providers/driver_earnings_provider.dart';
import 'providers/wallet_provider.dart';

/// Driver Wallet: real-time balance card, withdraw button, line chart (7 days), transaction list.
class DriverWalletScreen extends ConsumerStatefulWidget {
  const DriverWalletScreen({super.key});

  @override
  ConsumerState<DriverWalletScreen> createState() => _DriverWalletScreenState();
}

class _DriverWalletScreenState extends ConsumerState<DriverWalletScreen> {
  RealtimeChannel? _walletChannel;

  @override
  void dispose() {
    _walletChannel?.unsubscribe();
    super.dispose();
  }

  void _subscribeWalletRealtime(int walletId) {
    _walletChannel?.unsubscribe();
    final client = ref.read(supabaseClientProvider);
    _walletChannel = client
        .channel('wallet-$walletId')
        .onPostgresChanges(
          schema: 'public',
          table: 'wallets',
          event: PostgresChangeEvent.update,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: walletId,
          ),
          callback: (_) {
            ref.invalidate(driverWalletProvider);
            ref.invalidate(driverTransactionsProvider);
          },
        )
        .subscribe();
  }

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(driverWalletProvider);
    final transactionsAsync = ref.watch(driverTransactionsProvider);

    walletAsync.whenData((wallet) {
      if (wallet != null && _walletChannel == null) {
        _subscribeWalletRealtime(wallet.id);
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('wallet'.tr()),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(driverWalletProvider);
          ref.invalidate(driverTransactionsProvider);
          final driverId = ref.read(driverIdProvider);
          if (driverId != null) ref.invalidate(driverCompletedBookingsProvider(driverId));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            walletAsync.when(
              data: (wallet) => _BalanceCard(wallet: wallet),
              loading: () => const _BalanceCardShimmer(),
              error: (_, __) => const _BalanceCard(wallet: null),
            ),
            const SizedBox(height: 16),
            walletAsync.when(
              data: (wallet) => _WithdrawButton(wallet: wallet),
              loading: () => const SizedBox.shrink(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 24),
            Text(
              'last_7_days'.tr(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 200,
              child: transactionsAsync.when(
                data: (txns) => _EarningsLineChart(transactions: txns),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => Center(child: Text('chart_load_error'.tr())),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'İşlem geçmişi',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            transactionsAsync.when(
              data: (txns) => txns.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'Henüz işlem yok',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                              ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: txns.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) => _WalletTransactionTile(transaction: txns[i]),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Hata: $e', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({this.wallet});

  final Wallet? wallet;

  @override
  Widget build(BuildContext context) {
    final balance = wallet?.availableBalance ?? 0.0;
    final totalEarned = wallet?.totalEarned ?? 0.0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'withdrawable_balance'.tr(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.8),
                ),
          ),
          const SizedBox(height: 8),
          Text(
            '${balance.toStringAsFixed(2)} ${AppConstants.currencySymbol}',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: 16),
          Text(
            '${'total_earned_label'.tr()}: ${totalEarned.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onPrimaryContainer.withValues(alpha: 0.7),
                ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCardShimmer extends StatelessWidget {
  const _BalanceCardShimmer();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _WithdrawButton extends ConsumerStatefulWidget {
  const _WithdrawButton({this.wallet});

  final Wallet? wallet;

  @override
  ConsumerState<_WithdrawButton> createState() => _WithdrawButtonState();
}

class _WithdrawButtonState extends ConsumerState<_WithdrawButton> {
  bool _loading = false;

  Future<void> _showWithdrawDialog() async {
    if (widget.wallet == null) return;
    final balance = widget.wallet!.availableBalance;
    if (balance <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('insufficient_balance'.tr())),
        );
      }
      return;
    }

    final amount = await showDialog<double>(
      context: context,
      builder: (context) => _WithdrawAmountDialog(maxAmount: balance),
    );
    if (amount == null || amount <= 0 || !mounted) return;

    setState(() => _loading = true);
    try {
      final driverId = ref.read(driverIdProvider);
      if (driverId == null) throw Exception('Oturum yok');
      final client = ref.read(supabaseClientProvider);
      final res = await requestWithdrawal(driverId: driverId, amount: amount, client: client);
      if (mounted) {
        ref.invalidate(driverWalletProvider);
        ref.invalidate(driverTransactionsProvider);
        final ok = res['ok'] as bool? ?? false;
        if (ok) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('withdrawal_request_received'.tr()),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(res['error'] as String? ?? 'transaction_failed'.tr())),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balance = widget.wallet?.availableBalance ?? 0.0;

    return FilledButton.icon(
      onPressed: (_loading || balance <= 0) ? null : _showWithdrawDialog,
      icon: _loading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : const Icon(Icons.account_balance_wallet),
      label: Text('withdraw'.tr()),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

class _WithdrawAmountDialog extends StatefulWidget {
  const _WithdrawAmountDialog({required this.maxAmount});

  final double maxAmount;

  @override
  State<_WithdrawAmountDialog> createState() => _WithdrawAmountDialogState();
}

class _WithdrawAmountDialogState extends State<_WithdrawAmountDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.maxAmount.toStringAsFixed(0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('withdrawal_request'.tr()),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${'max_label'.tr()}: ${widget.maxAmount.toStringAsFixed(0)} ${AppConstants.currencySymbol}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'amount_label'.tr(),
              suffixText: AppConstants.currencySymbol,
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('cancel'.tr()),
        ),
        FilledButton(
          onPressed: () {
            final v = double.tryParse(_controller.text.replaceAll(',', '.')) ?? 0;
            if (v > 0 && v <= widget.maxAmount) {
              Navigator.of(context).pop(v);
            }
          },
          child: Text('request_withdraw'.tr()),
        ),
      ],
    );
  }
}

/// Line chart: last 7 days earnings from transactions (credits per day).
class _EarningsLineChart extends StatelessWidget {
  const _EarningsLineChart({required this.transactions});

  final List<WalletTransaction> transactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final dailySums = List<double>.filled(7, 0);
    for (var i = 0; i < 7; i++) {
      final dayStart = todayStart.subtract(Duration(days: 6 - i));
      final dayEnd = dayStart.add(const Duration(days: 1));
      for (final t in transactions) {
        if (t.createdAt == null || t.amount <= 0) continue;
        final d = t.createdAt!.isUtc ? t.createdAt!.toLocal() : t.createdAt!;
        if (d.isAfter(dayStart.subtract(const Duration(seconds: 1))) && d.isBefore(dayEnd)) {
          dailySums[i] += t.amount;
        }
      }
    }

    final maxY = dailySums.isEmpty ? 1.0 : dailySums.reduce((a, b) => a > b ? a : b);
    final top = maxY <= 0 ? 1.0 : maxY * 1.2;
    final spots = [
      for (var i = 0; i < 7; i++) FlSpot(i.toDouble(), dailySums[i]),
    ];

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: 6,
        minY: 0,
        maxY: top,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i >= 0 && i < 7) {
                  final day = todayStart.subtract(Duration(days: 6 - i));
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${day.day}/${day.month}',
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
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.green.shade700,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.green.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
      duration: const Duration(milliseconds: 300),
    );
  }
}

String _formatTxnDate(DateTime? d) {
  if (d == null) return '—';
  final local = d.isUtc ? d.toLocal() : d;
  const months = ['Oca', 'Şub', 'Mar', 'Nis', 'May', 'Haz', 'Tem', 'Ağu', 'Eyl', 'Eki', 'Kas', 'Ara'];
  final m = local.month >= 1 && local.month <= 12 ? months[local.month - 1] : '';
  return '${local.day} $m, ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}

String _transactionTitle(WalletTransaction t) {
  switch (t.type) {
    case 'booking_credit':
      return t.description ?? 'İş tamamlandı';
    case 'withdrawal':
      return t.status == 'pending_admin_approval'
          ? 'Çekim talebi (onay bekliyor)'
          : t.description ?? 'Para çekme';
    case 'withdrawal_fee':
      return 'Ücret';
    case 'adjustment':
      return t.description ?? 'Düzeltme';
    default:
      return t.description ?? t.type;
  }
}

class _WalletTransactionTile extends StatelessWidget {
  const _WalletTransactionTile({required this.transaction});

  final WalletTransaction transaction;

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final amountColor = isCredit ? Colors.green.shade700 : Colors.red.shade700;
    final amountStr = '${transaction.amount.abs().toStringAsFixed(0)} ${AppConstants.currencySymbol}';
    if (!isCredit) {
      // Show negative with minus or just the absolute value with red
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 0),
      leading: CircleAvatar(
        backgroundColor: isCredit
            ? Colors.green.withValues(alpha: 0.2)
            : Colors.red.withValues(alpha: 0.2),
        child: Icon(
          isCredit ? Icons.add : Icons.remove,
          color: amountColor,
          size: 22,
        ),
      ),
      title: Text(
        _transactionTitle(transaction),
        style: Theme.of(context).textTheme.bodyMedium,
      ),
      subtitle: Text(
        _formatTxnDate(transaction.createdAt),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
      ),
      trailing: Text(
        '${isCredit ? '+' : '-'}$amountStr',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: amountColor,
            ),
      ),
    );
  }
}
