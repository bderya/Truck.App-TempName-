import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';
import '../../auth/providers/auth_state_provider.dart';

/// Fetches saved payment methods for the current user from user_payment_methods.
final userPaymentMethodsProvider = FutureProvider<List<UserPaymentMethod>>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = await ref.read(currentAppUserProvider.future);
  if (user == null) return [];

  final res = await client
      .from('user_payment_methods')
      .select()
      .eq('user_id', user.id)
      .order('is_default', ascending: false)
      .order('created_at', ascending: false);

  return (res as List<dynamic>)
      .map((e) => UserPaymentMethod.fromJson(e as Map<String, dynamic>))
      .toList();
});
