import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../providers/admin_providers.dart';

class DriversScreen extends ConsumerStatefulWidget {
  const DriversScreen({super.key});

  @override
  ConsumerState<DriversScreen> createState() => _DriversScreenState();
}

class _DriversScreenState extends ConsumerState<DriversScreen> {
  final Set<int> _updating = {};

  Future<void> _toggleVerified(User driver) async {
    if (_updating.contains(driver.id)) return;
    setState(() => _updating.add(driver.id));

    try {
      await adminApproveUser(driver.id, driver.isVerified ? 'rejected' : 'approved');
      ref.invalidate(adminDriversProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(driver.id));
    }
  }

  void _showReviewDocuments(BuildContext context, User driver) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Documents – ${driver.fullName}'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (driver.licenseImageUrl != null)
                _DocRow('License', driver.licenseImageUrl!),
              if (driver.criminalRecordUrl != null)
                _DocRow('Criminal record', driver.criminalRecordUrl!),
              if (driver.licenseImageUrl == null && driver.criminalRecordUrl == null)
                const Text('No documents uploaded.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final driversAsync = ref.watch(adminDriversProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: driversAsync.when(
        data: (drivers) => _DriversTable(
          drivers: drivers,
          updating: _updating,
          onToggleVerified: _toggleVerified,
          onReviewDocuments: _showReviewDocuments,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DocRow extends StatelessWidget {
  const _DocRow(this.label, this.url);

  final String label;
  final String url;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          SelectableText(url, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        ],
      ),
    );
  }
}

class _DriversTable extends StatelessWidget {
  const _DriversTable({
    required this.drivers,
    required this.updating,
    required this.onToggleVerified,
    required this.onReviewDocuments,
  });

  final List<User> drivers;
  final Set<int> updating;
  final void Function(User) onToggleVerified;
  final void Function(BuildContext, User) onReviewDocuments;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('Name')),
            DataColumn(label: Text('Phone')),
            DataColumn(label: Text('Status')),
            DataColumn(label: Text('Verified')),
            DataColumn(label: Text('Actions')),
          ],
          rows: drivers.map((d) {
            final isUpdating = updating.contains(d.id);
            return DataRow(
              cells: [
                DataCell(Text('${d.id}')),
                DataCell(Text(d.fullName)),
                DataCell(Text(d.phoneNumber)),
                DataCell(Text(d.status)),
                DataCell(
                  Switch(
                    value: d.isVerified,
                    onChanged: isUpdating ? null : (_) => onToggleVerified(d),
                  ),
                ),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      FilledButton.tonal(
                        onPressed: () => onReviewDocuments(context, d),
                        child: const Text('Review Documents'),
                      ),
                      if (isUpdating) const SizedBox(width: 8),
                      if (isUpdating)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }
}
