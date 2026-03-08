import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/models.dart' show User;

final RegExp _phoneE164Regex = RegExp(r'^\+?[1-9]\d{6,14}$');
final RegExp _nationalNumberRegex = RegExp(r'^[0-9]{7,15}$');

class AuthService {
  AuthService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Returns true if [nationalNumber] is valid (7–15 digits).
  bool isValidPhoneNumber(String nationalNumber) {
    final digits = nationalNumber.replaceAll(RegExp(r'\D'), '');
    return _nationalNumberRegex.hasMatch(digits);
  }

  /// Returns full E.164 phone (e.g. +905551234567). [countryCode] is e.g. +90.
  String toE164(String countryCode, String nationalNumber) {
    final code = countryCode.startsWith('+') ? countryCode : '+$countryCode';
    final digits = nationalNumber.replaceAll(RegExp(r'\D'), '');
    return '$code$digits';
  }

  /// Validates E.164 string.
  bool isValidE164(String e164) => _phoneE164Regex.hasMatch(e164.replaceAll(RegExp(r'\s'), ''));

  /// Sends OTP to [phoneE164]. Phone must be E.164 (e.g. +905551234567).
  Future<void> sendOtp(String phoneE164) async {
    if (!isValidE164(phoneE164)) {
      throw ArgumentError('Invalid phone number');
    }
    await _client.auth.signInWithOtp(phone: phoneE164);
  }

  /// Verifies OTP and returns the session. [phoneE164] same as sent, [token] 6-digit code.
  Future<AuthResponse> verifyOtp(String phoneE164, String token) async {
    if (!isValidE164(phoneE164)) {
      throw ArgumentError('Invalid phone number');
    }
    return _client.auth.verifyOtp(
      phone: phoneE164,
      token: token.trim(),
      type: OtpType.sms,
    );
  }

  /// Current session (persisted by Supabase Flutter SDK).
  Session? get currentSession => _client.auth.currentSession;

  /// Current Supabase auth user (phone in user metadata).
  dynamic get currentAuthUser => _client.auth.currentUser;

  /// Sign out and clear session.
  Future<void> signOut() => _client.auth.signOut();

  /// Fetches app user from public.users by [phoneNumber] (same format as in DB).
  Future<User?> getUserByPhone(String phoneNumber) async {
    final res = await _client
        .from('users')
        .select()
        .eq('phone_number', phoneNumber)
        .maybeSingle();
    if (res == null) return null;
    return User.fromJson(res as Map<String, dynamic>);
  }

  /// Creates a new user in public.users (Complete Profile). [userType] default 'client'.
  Future<User> createUser({
    required String phoneNumber,
    required String fullName,
    String? email,
    String userType = 'client',
  }) async {
    final res = await _client.from('users').insert({
      'phone_number': phoneNumber,
      'full_name': fullName,
      if (email != null && email.isNotEmpty) 'email': email,
      'user_type': userType,
    }).select().single();
    return User.fromJson(res as Map<String, dynamic>);
  }
}
