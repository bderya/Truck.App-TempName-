import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants.dart';
import '../../../core/providers.dart';
import '../../../features/auth/providers/auth_state_provider.dart';
import '../../../models/models.dart';
import '../../../services/review_service.dart';
import '../widgets/review_rating_and_feedback.dart';
import 'job_summary_receipt_screen.dart';

/// Post-job summary: star rating, comment, tags, and optional tip.
/// Shown after payment is successful (booking completed). Submits to [reviews] table.
class PostJobSummaryScreen extends ConsumerStatefulWidget {
  const PostJobSummaryScreen({
    super.key,
    required this.booking,
    this.driverName,
  });

  final Booking booking;
  final String? driverName;

  @override
  ConsumerState<PostJobSummaryScreen> createState() => _PostJobSummaryScreenState();
}

class _PostJobSummaryScreenState extends ConsumerState<PostJobSummaryScreen> {
  int _rating = 0;
  final _commentController = TextEditingController();
  final List<String> _selectedTags = [];
  double? _tipAmount;
  bool _submitting = false;
  bool _tipSending = false;

  static const List<String> _tagOptionKeys = [
    'tag_on_time',
    'tag_professional',
    'tag_clean_truck',
    'tag_friendly',
    'tag_issue',
  ];

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (widget.booking.driverId == null) return;
    final clientId = widget.booking.clientId;
    setState(() => _submitting = true);
    final ok = await submitReview(
      client: ref.read(supabaseClientProvider),
      bookingId: widget.booking.id,
      driverId: widget.booking.driverId!,
      clientId: clientId,
      rating: _rating > 0 ? _rating : 3,
      comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      tags: _selectedTags.isEmpty ? null : _selectedTags,
    );
    if (!mounted) return;
    setState(() => _submitting = false);
    if (ok && _tipAmount != null && _tipAmount! > 0) {
      await _sendTip();
    }
    if (mounted) _goToReceipt();
  }

  Future<void> _sendTip() async {
    if (_tipAmount == null || _tipAmount! <= 0 || widget.booking.driverId == null) return;
    final user = await ref.read(currentAppUserProvider.future);
    final cardTokenId = user?.defaultCardTokenId;
    if (cardTokenId == null || cardTokenId.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('tip_need_card'.tr())),
        );
      }
      return;
    }
    setState(() => _tipSending = true);
    try {
      final res = await ref.read(supabaseClientProvider).functions.invoke(
            'process-tip',
            body: {
              'bookingId': widget.booking.id,
              'driverId': widget.booking.driverId,
              'amount': _tipAmount,
              'cardTokenId': cardTokenId,
              'currency': 'try',
            },
          );
      if (!mounted) return;
      if (res.status == 200 && (res.data as Map?)?['ok'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${'tip_sent'.tr()}: ${AppConstants.currencySymbol}${_tipAmount!.toStringAsFixed(0)}'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text((res.data as Map?)?['error'] as String? ?? 'tip_failed'.tr()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('tip_failed'.tr()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _tipSending = false);
    }
  }

  void _goToReceipt() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => JobSummaryReceiptScreen(bookingId: widget.booking.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('rate_experience_title'.tr()),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => _goToReceipt(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'rate_experience_thanks'.tr() + (widget.driverName != null ? ' ' + 'rate_experience_with_driver'.tr(namedArgs: {'driver': widget.driverName!}) : ''),
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            ReviewRatingAndFeedback(
              rating: _rating,
              onRatingChanged: (v) => setState(() => _rating = v),
              commentController: _commentController,
              selectedTags: _selectedTags,
              tagOptionKeys: _tagOptionKeys,
              onTagToggle: (tag) {
                setState(() {
                  if (_selectedTags.contains(tag)) {
                    _selectedTags.remove(tag);
                  } else {
                    _selectedTags.add(tag);
                  }
                });
              },
            ),
            const SizedBox(height: 32),
            _buildTipSection(),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: _submitting ? null : _submitReview,
              style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              child: _submitting
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text('submit_and_receipt'.tr()),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _submitting ? null : _goToReceipt,
              child: Text('skip'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTipSection() {
    const presets = [20.0, 50.0, 100.0];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'send_tip_label'.tr(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'tip_disclaimer'.tr(),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ...presets.map((amount) {
              final selected = _tipAmount == amount;
              return ChoiceChip(
                label: Text('${AppConstants.currencySymbol}${amount.toInt()}'),
                selected: selected,
                onSelected: _tipSending
                    ? null
                    : (v) => setState(() => _tipAmount = v ? amount : null),
              );
            }),
            ChoiceChip(
              label: Text('tip_custom'.tr()),
              selected: _tipAmount != null && !presets.contains(_tipAmount),
              onSelected: _tipSending
                  ? null
                  : (_) {
                      setState(() => _tipAmount = null);
                      _showCustomTipDialog();
                    },
            ),
          ],
        ),
      ],
    );
  }

  void _showCustomTipDialog() {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('tip_amount_label'.tr()),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '${'amount_label'.tr()} (TL)',
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('cancel'.tr())),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
              if (value > 0) setState(() => _tipAmount = value);
              Navigator.pop(ctx);
            },
            child: Text('ok'.tr()),
          ),
        ],
      ),
    );
  }
}
