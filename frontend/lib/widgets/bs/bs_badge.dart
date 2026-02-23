import 'package:flutter/material.dart';

import '../../ui/bootstrap_colors.dart';
import '../../ui/bootstrap_tokens.dart';

class BsBadge extends StatelessWidget {
  const BsBadge({
    super.key,
    required this.label,
    this.variant = BsVariant.secondary,
    this.pill = true,
  });

  final String label;
  final BsVariant variant;
  final bool pill;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    final color = bsVariantColor(variant);
    final foreground = bsVariantOnColor(variant);
    return Container(
      padding: tokens?.badgePadding ??
          const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius:
            BorderRadius.circular(pill ? 999 : (tokens?.radiusSm ?? 6)),
      ),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelSmall
            ?.copyWith(color: foreground),
      ),
    );
  }
}
