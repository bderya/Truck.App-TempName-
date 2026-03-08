import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';
import 'driver_booking_provider.dart';

/// Fetches or creates wallet for driver. Balance updates via trigger when booking completed.
Future<Wallet?> fetchDriverWallet(int driverId) async {
  final client = Supabase.instance.client;
  final rpc = await client.rpc('get_or_create_wallet', params: {'p_driver_id': driverId});
  if (rpc is Map<String, dynamic> && rpc['ok'] == true && rpc['wallet'] != null) {
    return Wallet.fromJson(rpc['wallet'] as Map<String, dynamic>);
  }
  final res = await client
      .from('wallets')
      .select()
      .eq('driver_id', driverId)
      .maybeSingle();
  if (res == null) return null;
  return Wallet.fromJson(res as Map<String, dynamic>);
}

/// Recent transactions for a wallet (credits green, debits red).
Future<List<WalletTransaction>> fetchWalletTransactions(int walletId, {int limit = 50}) async {
  final client = Supabase.instance.client;
  final res = await client
      .from('transactions')
      .select()
      .eq('wallet_id', walletId)
      .order('created_at', ascending: false)
      .limit(limit);
  if (res == null || res is! List) return [];
  return (res as List)
      .map((e) => WalletTransaction.fromJson(e as Map<String, dynamic>))
      .toList();
}

/// Current driver's wallet (real-time: refetch when invalided).
final driverWalletProvider = FutureProvider<Wallet?>((ref) async {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null) return null;
  return fetchDriverWallet(driverId);
});

/// Current driver's wallet transactions. Depends on wallet.
final driverTransactionsProvider = FutureProvider<List<WalletTransaction>>((ref) async {
  final walletAsync = ref.watch(driverWalletProvider);
  final wallet = walletAsync.valueOrNull;
  if (wallet == null) return [];
  return fetchWalletTransactions(wallet.id);
});

/// Request withdrawal: calls RPC, deducts balance, transaction status = pending_admin_approval.
Future<Map<String, dynamic>> requestWithdrawal({
  required int driverId,
  required double amount,
  required SupabaseClient client,
}) async {
  final res = await client.rpc('request_withdrawal', params: {
    'p_driver_id': driverId,
    'p_amount': amount,
  });
  if (res is Map<String, dynamic>) return res;
  return {'ok': false, 'error': 'Invalid response'};
}
