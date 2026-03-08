import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';

/// Auth state: no session, session but no app profile, or session + profile.
enum AuthStatus { initial, unauthenticated, needsProfile, authenticated }

Future<AuthStatus> _computeStatus(Ref ref) async {
  final client = ref.read(supabaseClientProvider);
  final session = client.auth.currentSession;
  final user = client.auth.currentUser;
  if (session == null || user == null) return AuthStatus.unauthenticated;
  final phone = user.phone;
  if (phone == null || phone.isEmpty) return AuthStatus.unauthenticated;
  final appUser = await ref.read(authServiceProvider).getUserByPhone(phone);
  return appUser == null ? AuthStatus.needsProfile : AuthStatus.authenticated;
}

/// Exposes current auth status. Session is persisted by Supabase (secure storage).
final authStatusProvider = StreamProvider<AuthStatus>((ref) async* {
  yield await _computeStatus(ref);

  final client = ref.read(supabaseClientProvider);
  await for (final _ in client.auth.onAuthStateChange) {
    yield await _computeStatus(ref);
  }
});

/// Current app user (from public.users). Only valid when status is authenticated.
final currentAppUserProvider = FutureProvider<User?>((ref) async {
  final client = ref.read(supabaseClientProvider);
  final user = client.auth.currentUser;
  final phone = user?.phone;
  if (phone == null || phone.isEmpty) return null;
  return ref.read(authServiceProvider).getUserByPhone(phone);
});
