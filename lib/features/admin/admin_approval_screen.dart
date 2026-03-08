import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple admin screen to approve/reject driver verification.
/// Call RPCs: approve_user(user_id, status) and set_user_verified(user_id, verified).
class AdminApprovalScreen extends StatefulWidget {
  const AdminApprovalScreen({super.key});

  @override
  State<AdminApprovalScreen> createState() => _AdminApprovalScreenState();
}

class _AdminApprovalScreenState extends State<AdminApprovalScreen> {
  final _userIdController = TextEditingController();
  String _status = 'approved';
  String? _message;
  bool _loading = false;

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _approveUser() async {
    final id = int.tryParse(_userIdController.text.trim());
    if (id == null) {
      setState(() => _message = 'Enter a valid user ID');
      return;
    }

    setState(() {
      _loading = true;
      _message = null;
    });

    try {
      final res = await Supabase.instance.client.rpc(
        'approve_user',
        params: {'p_user_id': id, 'p_status': _status},
      );

      if (mounted) {
        setState(() {
          _loading = false;
          _message = res != null && res['ok'] == true
              ? 'Updated: status=$_status, is_verified=${res['is_verified']}'
              : 'Error: ${res?['error'] ?? 'Unknown'}';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _message = 'Error: $e';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin – Approval'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Set user verification status',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _userIdController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'User ID',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _status,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'pending', child: Text('Pending')),
                DropdownMenuItem(value: 'approved', child: Text('Approved')),
                DropdownMenuItem(value: 'rejected', child: Text('Rejected')),
              ],
              onChanged: (v) => setState(() => _status = v ?? 'approved'),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _loading ? null : _approveUser,
              child: _loading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Apply'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _message!.startsWith('Error')
                          ? Theme.of(context).colorScheme.error
                          : null,
                    ),
              ),
            ],
            const SizedBox(height: 32),
            Text(
              'From Supabase Dashboard SQL you can run:\n'
              "SELECT approve_user(123, 'approved');\n"
              "SELECT set_user_verified(123, true);",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
