import 'package:flutter/material.dart';

import '../../ui/bootstrap_colors.dart';
import '../../ui/bootstrap_tokens.dart';

class BsButton extends StatelessWidget {
  const BsButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = BsVariant.primary,
    this.outline = false,
    this.fullWidth = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final BsVariant variant;
  final bool outline;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    final color = bsVariantColor(variant);
    final foreground = outline ? color : bsVariantOnColor(variant);
    final background = outline ? Colors.transparent : color;

    final style = ButtonStyle(
      foregroundColor: MaterialStateProperty.resolveWith(
        (states) {
          if (states.contains(MaterialState.disabled)) {
            return foreground.withOpacity(0.6);
          }
          return foreground;
        },
      ),
      backgroundColor: MaterialStateProperty.resolveWith(
        (states) {
          if (states.contains(MaterialState.disabled)) {
            return background == Colors.transparent
                ? Colors.transparent
                : background.withOpacity(0.5);
          }
          return background;
        },
      ),
      shadowColor: const MaterialStatePropertyAll(Colors.transparent),
      padding: MaterialStatePropertyAll(
        tokens?.buttonPadding ??
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      shape: MaterialStatePropertyAll(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens?.radiusMd ?? 8),
          side: BorderSide(color: color),
        ),
      ),
      overlayColor: MaterialStateProperty.resolveWith(
        (states) {
          if (states.contains(MaterialState.pressed)) {
            return color.withOpacity(tokens?.pressedOpacity ?? 0.12);
          }
          if (states.contains(MaterialState.hovered)) {
            return color.withOpacity(tokens?.hoverOpacity ?? 0.08);
          }
          return null;
        },
      ),
    );

    final button = ElevatedButton(
      onPressed: onPressed,
      style: style,
      child: Text(label),
    );

    if (!fullWidth) {
      return button;
    }
    return SizedBox(width: double.infinity, child: button);
  }
}
