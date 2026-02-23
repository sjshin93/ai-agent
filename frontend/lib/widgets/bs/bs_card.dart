import 'package:flutter/material.dart';

import '../../ui/bootstrap_tokens.dart';

class BsCard extends StatelessWidget {
  const BsCard({
    super.key,
    required this.child,
    this.padding,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    return Card(
      child: Padding(
        padding: padding ?? tokens?.cardPadding ?? const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
