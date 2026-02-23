import 'package:flutter/material.dart';

enum BsVariant {
  primary,
  secondary,
  success,
  info,
  warning,
  danger,
  light,
  dark,
}

class BootstrapColors {
  static const primary = Color(0xFFE60044);
  static const secondary = Color(0xFF6C757D);
  static const success = Color(0xFF198754);
  static const info = Color(0xFF0DCAF0);
  static const warning = Color(0xFFFFC107);
  static const danger = Color(0xFFDC3545);
  static const light = Color(0xFFF8F9FA);
  static const dark = Color(0xFF212529);

  static const text = Color(0xFF212529);
  static const textMuted = Color(0xFF6C757D);
  static const border = Color(0xFFDEE2E6);
  static const background = Color(0xFFF8F9FA);
}

Color bsVariantColor(BsVariant variant) {
  return switch (variant) {
    BsVariant.primary => BootstrapColors.primary,
    BsVariant.secondary => BootstrapColors.secondary,
    BsVariant.success => BootstrapColors.success,
    BsVariant.info => BootstrapColors.info,
    BsVariant.warning => BootstrapColors.warning,
    BsVariant.danger => BootstrapColors.danger,
    BsVariant.light => BootstrapColors.light,
    BsVariant.dark => BootstrapColors.dark,
  };
}

Color bsVariantOnColor(BsVariant variant) {
  return switch (variant) {
    BsVariant.light => BootstrapColors.text,
    BsVariant.warning => BootstrapColors.text,
    _ => Colors.white,
  };
}
