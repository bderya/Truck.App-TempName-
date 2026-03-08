import 'package:flutter/material.dart';

/// Review popup shown to the customer when a booking is completed.
/// Optional star rating (can be sent to backend later).
class ReviewPopup extends StatefulWidget {
  const ReviewPopup({
    super.key,
    this.driverName,
    this.onSubmit,
    this.onDismiss,
  });

  final String? driverName;
  final void Function(int rating)? onSubmit;
  final VoidCallback? onDismiss;

  /// Shows the review dialog. Call when booking status becomes 'completed'.
  static Future<void> show(
    BuildContext context, {
    String? driverName,
    void Function(int rating)? onSubmit,
    VoidCallback? onDismiss,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => ReviewPopup(
        driverName: driverName,
        onSubmit: (rating) {
          Navigator.of(context).pop();
          onSubmit?.call(rating);
        },
        onDismiss: () {
          Navigator.of(context).pop();
          onDismiss?.call();
        },
      ),
    );
  }

  @override
  State<ReviewPopup> createState() => _ReviewPopupState();
}

class _ReviewPopupState extends State<ReviewPopup> {
  int _rating = 0;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Trip complete'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Thank you for using Cekici.'
              '${widget.driverName != null ? ' How was your experience with ${widget.driverName}?' : ''}',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            Text(
              'Rate your experience',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final star = i + 1;
                return IconButton(
                  onPressed: () => setState(() => _rating = star),
                  icon: Icon(
                    star <= _rating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                    size: 36,
                  ),
                );
              }),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: widget.onDismiss,
          child: const Text('Skip'),
        ),
        FilledButton(
          onPressed: () => widget.onSubmit?.call(_rating > 0 ? _rating : 0),
          child: Text(_rating > 0 ? 'Submit' : 'Done'),
        ),
      ],
    );
  }
}
