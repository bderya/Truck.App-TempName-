import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

/// Star rating row, optional comment field, and tag chips for reviews.
class ReviewRatingAndFeedback extends StatelessWidget {
  const ReviewRatingAndFeedback({
    super.key,
    required this.rating,
    required this.onRatingChanged,
    required this.commentController,
    required this.selectedTags,
    required this.tagOptionKeys,
    required this.onTagToggle,
  });

  final int rating;
  final ValueChanged<int> onRatingChanged;
  final TextEditingController commentController;
  final List<String> selectedTags;
  final List<String> tagOptionKeys;
  final ValueChanged<String> onTagToggle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'rate_stars_label'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(5, (i) {
            final star = i + 1;
            return IconButton(
              onPressed: () => onRatingChanged(star),
              icon: Icon(
                star <= rating ? Icons.star : Icons.star_border,
                color: Colors.amber,
                size: 40,
              ),
            );
          }),
        ),
        const SizedBox(height: 20),
        Text(
          'comment_optional'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: commentController,
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'comment_hint'.tr(),
            border: const OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'tags_label'.tr(),
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: tagOptionKeys.map((key) {
            final selected = selectedTags.contains(key);
            return FilterChip(
              label: Text(key.tr()),
              selected: selected,
              onSelected: (_) => onTagToggle(key),
            );
          }).toList(),
        ),
      ],
    );
  }
}
