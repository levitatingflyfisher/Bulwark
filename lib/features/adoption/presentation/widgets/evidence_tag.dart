import 'package:flutter/material.dart';

import 'package:bulwark/features/library/domain/enums.dart';
import 'package:bulwark/shared/theme/app_colors.dart';

/// A small, non-judgmental strength-of-evidence marker. Rendered as an inline
/// dot + flexible label so it wraps rather than overflowing at large text
/// scales on narrow screens (the fleet's known 320 dp / 3× overflow class).
/// Deliberately neutral: the label carries the meaning, the styling does not
/// rank one habit above another.
class EvidenceTag extends StatelessWidget {
  const EvidenceTag(this.evidence, {super.key});

  final Evidence evidence;

  static String label(Evidence e) => switch (e) {
        Evidence.rct => 'Randomized trials',
        Evidence.observational => 'Observational',
        Evidence.mechanistic => 'Mechanistic',
        Evidence.traditional => 'Traditional',
      };

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context)
        .textTheme
        .labelSmall
        ?.copyWith(color: AppColors.stone);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: AppColors.stone,
              shape: BoxShape.circle,
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Evidence: ${label(evidence)}',
            style: style,
            softWrap: true,
          ),
        ),
      ],
    );
  }
}
