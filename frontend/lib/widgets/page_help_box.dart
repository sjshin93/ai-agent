import 'package:flutter/material.dart';

import '../ui/bootstrap_colors.dart';
import 'bs/bs_alert.dart';
import 'bs/bs_text.dart';

class PageHelpBox extends StatelessWidget {
  const PageHelpBox({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const BsText('Help', variant: BsTextVariant.subtitle),
        const SizedBox(height: 8),
        BsAlert(
          message: message,
          variant: BsVariant.info,
        ),
      ],
    );
  }
}
