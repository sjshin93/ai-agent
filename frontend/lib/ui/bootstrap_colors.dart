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
  // Logo-driven warm palette: yellow + light brown + orange.
  static const primary = Color(0xFFF6E000);
  static const secondary = Color(0xFF3D1D12);
  static const success = Color(0xFFC99846);
  static const info = Color(0xFFE1B46A);
  static const warning = Color(0xFFE28C2A);
  static const danger = Color(0xFFA04E2A);
  static const light = Color(0xFFFFF8E7);
  static const dark = Color(0xFF2A130C);

  static const text = Color(0xFF2A130C);
  static const textMuted = Color(0xFF6E503A);
  static const border = Color(0xFFE7D7B7);
  static const background = Color(0xFFFFF6DF);
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
    BsVariant.primary => BootstrapColors.text,
    BsVariant.light => BootstrapColors.text,
    BsVariant.warning => BootstrapColors.text,
    _ => Colors.white,
  };
}
