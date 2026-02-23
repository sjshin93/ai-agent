import 'package:flutter/material.dart';

import '../../ui/bootstrap_tokens.dart';

enum BsTextVariant {
  display,
  title,
  subtitle,
  body,
  caption,
  muted,
}

class BsText extends StatelessWidget {
  const BsText(
    this.text, {
    super.key,
    this.variant = BsTextVariant.body,
    this.textAlign,
    this.maxLines,
    this.overflow,
  });

  final String text;
  final BsTextVariant variant;
  final TextAlign? textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    final theme = Theme.of(context).textTheme;
    final style = switch (variant) {
      BsTextVariant.display => theme.displaySmall,
      BsTextVariant.title => theme.titleLarge,
      BsTextVariant.subtitle => theme.titleMedium,
      BsTextVariant.body => theme.bodyMedium,
      BsTextVariant.caption => theme.bodySmall,
      BsTextVariant.muted => theme.bodySmall?.copyWith(
          color: Theme.of(context)
              .colorScheme
              .onSurface
              .withOpacity(tokens?.mutedOpacity ?? 0.6),
        ),
    };

    return Text(
      text,
      style: style,
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
