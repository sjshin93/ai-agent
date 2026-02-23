import 'package:flutter/material.dart';

import '../../ui/bootstrap_colors.dart';
import '../../ui/bootstrap_tokens.dart';

class BsDropdown<T> extends StatelessWidget {
  const BsDropdown({
    super.key,
    required this.label,
    required this.items,
    required this.onSelected,
    this.value,
    this.enabled = true,
    this.menuOffset = const Offset(0, 8),
    this.menuConstraints,
    this.menuColor,
    this.menuShape,
    this.menuElevation,
  });

  final String label;
  final List<PopupMenuEntry<T>> items;
  final ValueChanged<T> onSelected;
  final T? value;
  final bool enabled;
  final Offset menuOffset;
  final BoxConstraints? menuConstraints;
  final Color? menuColor;
  final ShapeBorder? menuShape;
  final double? menuElevation;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    final inputTheme = Theme.of(context).inputDecorationTheme;
    final popupTheme = Theme.of(context).popupMenuTheme;
    final border = inputTheme.border ?? const OutlineInputBorder();
    final shape = menuShape ??
        popupTheme.shape ??
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens?.radiusSm ?? 6),
          side: const BorderSide(color: BootstrapColors.border),
        );
    return PopupMenuButton<T>(
      onSelected: enabled ? onSelected : null,
      enabled: enabled,
      itemBuilder: (_) => items,
      offset: menuOffset,
      constraints: menuConstraints,
      color: menuColor ?? popupTheme.color ?? Colors.white,
      shape: shape,
      elevation: menuElevation ?? popupTheme.elevation ?? tokens?.menuElevation,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: border,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value?.toString() ?? 'Select',
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
