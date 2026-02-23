import 'package:flutter/material.dart';

import '../../ui/bootstrap_colors.dart';
import '../../ui/bootstrap_tokens.dart';

class BsAlert extends StatelessWidget {
  const BsAlert({
    super.key,
    required this.message,
    this.variant = BsVariant.info,
  });

  final String message;
  final BsVariant variant;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    final color = bsVariantColor(variant);
    final foreground = bsVariantOnColor(variant);
    return Container(
      padding: tokens?.alertPadding ?? const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(tokens?.alertFillOpacity ?? 0.12),
        borderRadius: BorderRadius.circular(tokens?.radiusMd ?? 8),
        border: Border.all(color: color),
      ),
      child: Text(
        message,
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: foreground == Colors.white ? color : foreground),
      ),
    );
  }
}
