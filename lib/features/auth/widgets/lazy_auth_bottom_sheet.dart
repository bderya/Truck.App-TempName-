import 'package:country_code_picker/country_code_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../models/models.dart';

/// Lazy registration: bottom sheet with phone + SMS OTP.
/// On success ensures a user in [users] with [user_type: 'client'] and returns it.
/// Use when "Request Tow" is clicked and no client is logged in.
class LazyAuthBottomSheet extends ConsumerStatefulWidget {
  const LazyAuthBottomSheet({super.key});

  @override
  ConsumerState<LazyAuthBottomSheet> createState() => _LazyAuthBottomSheetState();
}

class _LazyAuthBottomSheetState extends ConsumerState<LazyAuthBottomSheet> {
  final _numberController = TextEditingController();
  final _otpController = TextEditingController();
  String _countryCode = '+90';
  bool _otpSent = false;
  String _phoneE164 = '';
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _numberController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final auth = ref.read(authServiceProvider);
    final national = _numberController.text.trim().replaceAll(RegExp(r'\D'), '');
    if (!auth.isValidPhoneNumber(national)) {
      setState(() => _error = 'Enter a valid phone number (7–15 digits)');
      return;
    }
    final e164 = auth.toE164(_countryCode, national);
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      await auth.sendOtp(e164);
      if (!mounted) return;
      setState(() {
        _phoneE164 = e164;
        _otpSent = true;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  Future<void> _verifyAndReturnClient() async {
    final token = _otpController.text.trim();
    if (token.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final auth = ref.read(authServiceProvider);
      await auth.verifyOtp(_phoneE164, token);
      User appUser = await auth.getUserByPhone(_phoneE164) ?? await auth.createUser(
            phoneNumber: _phoneE164,
            fullName: 'Client',
            userType: 'client',
          );
      if (!mounted) return;
      Navigator.of(context).pop(appUser);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString().replaceFirst('Exception: ', '');
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewPadding.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _otpSent ? 'Enter code' : 'Sign in with phone',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),
          if (!_otpSent)
            Text(
              'We\'ll send a one-time code to your number.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
          const SizedBox(height: 20),
          if (!_otpSent) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CountryCodePicker(
                  onChanged: (code) => setState(() => _countryCode = code.dialCode ?? '+90'),
                  initialSelection: 'TR',
                  showCountryOnly: false,
                  showOnlyCountryWhenClosed: false,
                  favorite: const ['+90', '+1', '+44'],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _numberController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '555 123 4567',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              'Code sent to $_phoneE164',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit code',
                hintText: '000000',
                border: OutlineInputBorder(),
                counterText: '',
              ),
              onChanged: (_) => setState(() => _error = null),
            ),
          ],
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.error,
                  ),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading
                ? null
                : (_otpSent ? _verifyAndReturnClient : _sendOtp),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : Text(_otpSent ? 'Verify and continue' : 'Send code'),
          ),
        ],
      ),
    );
  }
}

/// Shows the lazy auth bottom sheet. Returns the client [User] on success, null if dismissed.
Future<User?> showLazyAuthBottomSheet(BuildContext context) {
  return showModalBottomSheet<User>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => const LazyAuthBottomSheet(),
  );
}
