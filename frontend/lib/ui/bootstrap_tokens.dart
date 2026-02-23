import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

class BsTokens extends ThemeExtension<BsTokens> {
  const BsTokens({
    required this.radiusSm,
    required this.radiusMd,
    required this.buttonPadding,
    required this.inputPadding,
    required this.cardPadding,
    required this.listItemPadding,
    required this.tabPadding,
    required this.badgePadding,
    required this.alertPadding,
    required this.toastPadding,
    required this.menuPadding,
    required this.menuElevation,
    required this.hoverOverlay,
    required this.pressedOverlay,
    required this.hoverOpacity,
    required this.pressedOpacity,
    required this.alertFillOpacity,
    required this.toastOpacity,
    required this.mutedOpacity,
  });

  final double radiusSm;
  final double radiusMd;
  final EdgeInsets buttonPadding;
  final EdgeInsets inputPadding;
  final EdgeInsets cardPadding;
  final EdgeInsets listItemPadding;
  final EdgeInsets tabPadding;
  final EdgeInsets badgePadding;
  final EdgeInsets alertPadding;
  final EdgeInsets toastPadding;
  final EdgeInsets menuPadding;
  final double menuElevation;
  final Color hoverOverlay;
  final Color pressedOverlay;
  final double hoverOpacity;
  final double pressedOpacity;
  final double alertFillOpacity;
  final double toastOpacity;
  final double mutedOpacity;

  @override
  BsTokens copyWith({
    double? radiusSm,
    double? radiusMd,
    EdgeInsets? buttonPadding,
    EdgeInsets? inputPadding,
    EdgeInsets? cardPadding,
    EdgeInsets? listItemPadding,
    EdgeInsets? tabPadding,
    EdgeInsets? badgePadding,
    EdgeInsets? alertPadding,
    EdgeInsets? toastPadding,
    EdgeInsets? menuPadding,
    double? menuElevation,
    Color? hoverOverlay,
    Color? pressedOverlay,
    double? hoverOpacity,
    double? pressedOpacity,
    double? alertFillOpacity,
    double? toastOpacity,
    double? mutedOpacity,
  }) {
    return BsTokens(
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      buttonPadding: buttonPadding ?? this.buttonPadding,
      inputPadding: inputPadding ?? this.inputPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      listItemPadding: listItemPadding ?? this.listItemPadding,
      tabPadding: tabPadding ?? this.tabPadding,
      badgePadding: badgePadding ?? this.badgePadding,
      alertPadding: alertPadding ?? this.alertPadding,
      toastPadding: toastPadding ?? this.toastPadding,
      menuPadding: menuPadding ?? this.menuPadding,
      menuElevation: menuElevation ?? this.menuElevation,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      pressedOverlay: pressedOverlay ?? this.pressedOverlay,
      hoverOpacity: hoverOpacity ?? this.hoverOpacity,
      pressedOpacity: pressedOpacity ?? this.pressedOpacity,
      alertFillOpacity: alertFillOpacity ?? this.alertFillOpacity,
      toastOpacity: toastOpacity ?? this.toastOpacity,
      mutedOpacity: mutedOpacity ?? this.mutedOpacity,
    );
  }

  @override
  BsTokens lerp(ThemeExtension<BsTokens>? other, double t) {
    if (other is! BsTokens) {
      return this;
    }
    return BsTokens(
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      buttonPadding: EdgeInsets.lerp(buttonPadding, other.buttonPadding, t)!,
      inputPadding: EdgeInsets.lerp(inputPadding, other.inputPadding, t)!,
      cardPadding: EdgeInsets.lerp(cardPadding, other.cardPadding, t)!,
      listItemPadding:
          EdgeInsets.lerp(listItemPadding, other.listItemPadding, t)!,
      tabPadding: EdgeInsets.lerp(tabPadding, other.tabPadding, t)!,
      badgePadding: EdgeInsets.lerp(badgePadding, other.badgePadding, t)!,
      alertPadding: EdgeInsets.lerp(alertPadding, other.alertPadding, t)!,
      toastPadding: EdgeInsets.lerp(toastPadding, other.toastPadding, t)!,
      menuPadding: EdgeInsets.lerp(menuPadding, other.menuPadding, t)!,
      menuElevation: lerpDouble(menuElevation, other.menuElevation, t)!,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t)!,
      pressedOverlay: Color.lerp(pressedOverlay, other.pressedOverlay, t)!,
      hoverOpacity: lerpDouble(hoverOpacity, other.hoverOpacity, t)!,
      pressedOpacity: lerpDouble(pressedOpacity, other.pressedOpacity, t)!,
      alertFillOpacity:
          lerpDouble(alertFillOpacity, other.alertFillOpacity, t)!,
      toastOpacity: lerpDouble(toastOpacity, other.toastOpacity, t)!,
      mutedOpacity: lerpDouble(mutedOpacity, other.mutedOpacity, t)!,
    );
  }
}
