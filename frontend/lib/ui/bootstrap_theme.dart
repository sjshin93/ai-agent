import 'package:flutter/material.dart';

import 'bootstrap_colors.dart';
import 'bootstrap_tokens.dart';

class BootstrapTheme {
  static ThemeData light() {
    final base = ThemeData(
      brightness: Brightness.light,
      useMaterial3: true,
      fontFamily: 'NotoSansCJKkr',
    );

    const scheme = ColorScheme.light(
      primary: BootstrapColors.primary,
      secondary: BootstrapColors.secondary,
      surface: Colors.white,
      background: BootstrapColors.background,
      error: BootstrapColors.danger,
      onPrimary: BootstrapColors.text,
      onSecondary: Colors.white,
      onSurface: BootstrapColors.text,
      onBackground: BootstrapColors.text,
      onError: Colors.white,
    );

    final tokens = BsTokens(
      radiusSm: 6,
      radiusMd: 8,
      buttonPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      inputPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      cardPadding: const EdgeInsets.all(16),
      listItemPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tabPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      badgePadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      alertPadding: const EdgeInsets.all(12),
      toastPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      menuPadding: const EdgeInsets.all(4),
      menuElevation: 2,
      hoverOverlay: BootstrapColors.primary.withOpacity(0.08),
      pressedOverlay: BootstrapColors.primary.withOpacity(0.12),
      hoverOpacity: 0.08,
      pressedOpacity: 0.12,
      alertFillOpacity: 0.12,
      toastOpacity: 0.8,
      mutedOpacity: 0.6,
    );

    ButtonStyle _baseButtonStyle(Color color, Color onColor) {
      return ButtonStyle(
        foregroundColor: MaterialStateProperty.resolveWith(
          (states) {
            if (states.contains(MaterialState.disabled)) {
              return onColor.withOpacity(0.6);
            }
            return onColor;
          },
        ),
        backgroundColor: MaterialStateProperty.resolveWith(
          (states) {
            if (states.contains(MaterialState.disabled)) {
              return color.withOpacity(0.5);
            }
            return color;
          },
        ),
        padding: MaterialStatePropertyAll(tokens.buttonPadding),
        shape: MaterialStatePropertyAll(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(tokens.radiusMd),
            side: BorderSide(color: color),
          ),
        ),
        overlayColor: MaterialStateProperty.resolveWith(
          (states) {
            if (states.contains(MaterialState.pressed)) {
              return color.withOpacity(tokens.pressedOpacity);
            }
            if (states.contains(MaterialState.hovered)) {
              return color.withOpacity(tokens.hoverOpacity);
            }
            return null;
          },
        ),
        shadowColor: const MaterialStatePropertyAll(Colors.transparent),
      );
    }

    return base.copyWith(
      colorScheme: scheme,
      scaffoldBackgroundColor: BootstrapColors.background,
      hoverColor: tokens.hoverOverlay,
      focusColor: tokens.pressedOverlay,
      textTheme: base.textTheme.apply(
        bodyColor: BootstrapColors.text,
        displayColor: BootstrapColors.text,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.white,
        foregroundColor: BootstrapColors.text,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: _baseButtonStyle(scheme.primary, scheme.onPrimary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: _baseButtonStyle(scheme.primary, scheme.onPrimary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) {
              if (states.contains(MaterialState.disabled)) {
                return scheme.primary.withOpacity(0.5);
              }
              return scheme.primary;
            },
          ),
          padding: MaterialStatePropertyAll(tokens.buttonPadding),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
          ),
          side: MaterialStateProperty.resolveWith(
            (states) {
              final opacity =
                  states.contains(MaterialState.disabled) ? 0.5 : 1.0;
              return BorderSide(color: scheme.primary.withOpacity(opacity));
            },
          ),
          overlayColor: MaterialStateProperty.resolveWith(
            (states) {
              if (states.contains(MaterialState.pressed)) {
                return scheme.primary.withOpacity(tokens.pressedOpacity);
              }
              if (states.contains(MaterialState.hovered)) {
                return scheme.primary.withOpacity(tokens.hoverOpacity);
              }
              return null;
            },
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: MaterialStateProperty.resolveWith(
            (states) {
              if (states.contains(MaterialState.disabled)) {
                return scheme.primary.withOpacity(0.5);
              }
              return scheme.primary;
            },
          ),
          padding: MaterialStatePropertyAll(tokens.buttonPadding),
          overlayColor: MaterialStateProperty.resolveWith(
            (states) {
              if (states.contains(MaterialState.pressed)) {
                return scheme.primary.withOpacity(tokens.pressedOpacity);
              }
              if (states.contains(MaterialState.hovered)) {
                return scheme.primary.withOpacity(tokens.hoverOpacity);
              }
              return null;
            },
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          side: const BorderSide(color: BootstrapColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: tokens.inputPadding,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: const BorderSide(color: BootstrapColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: const BorderSide(color: BootstrapColors.border),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(
            color: BootstrapColors.border.withOpacity(0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: const BorderSide(color: BootstrapColors.primary),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(tokens.radiusMd),
          borderSide: BorderSide(color: scheme.error),
        ),
      ),
      tabBarTheme: TabBarThemeData(
        labelColor: scheme.primary,
        unselectedLabelColor: BootstrapColors.textMuted,
        indicator: UnderlineTabIndicator(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        indicatorSize: TabBarIndicatorSize.label,
        labelPadding: tokens.tabPadding,
        labelStyle: const TextStyle(fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500),
        dividerColor: BootstrapColors.border,
        overlayColor: MaterialStateProperty.resolveWith(
          (states) {
            if (states.contains(MaterialState.pressed)) {
              return scheme.primary.withOpacity(tokens.pressedOpacity);
            }
            if (states.contains(MaterialState.hovered)) {
              return scheme.primary.withOpacity(tokens.hoverOpacity);
            }
            return null;
          },
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.primary;
          }
          return Colors.white;
        }),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return scheme.primary.withOpacity(tokens.pressedOpacity);
          }
          if (states.contains(MaterialState.hovered)) {
            return scheme.primary.withOpacity(tokens.hoverOpacity);
          }
          return null;
        }),
        side: const BorderSide(color: BootstrapColors.border),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.primary;
          }
          return BootstrapColors.border;
        }),
        overlayColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.pressed)) {
            return scheme.primary.withOpacity(tokens.pressedOpacity);
          }
          if (states.contains(MaterialState.hovered)) {
            return scheme.primary.withOpacity(tokens.hoverOpacity);
          }
          return null;
        }),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.primary;
          }
          return BootstrapColors.border;
        }),
        trackColor: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return scheme.primary.withOpacity(0.4);
          }
          return BootstrapColors.border.withOpacity(0.6);
        }),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: Colors.white,
        elevation: tokens.menuElevation,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
          side: const BorderSide(color: BootstrapColors.border),
        ),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: const MaterialStatePropertyAll(Colors.white),
          elevation: MaterialStatePropertyAll(tokens.menuElevation),
          padding: MaterialStatePropertyAll(tokens.menuPadding),
          shape: MaterialStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(tokens.radiusSm),
              side: const BorderSide(color: BootstrapColors.border),
            ),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        contentPadding: tokens.listItemPadding,
        dense: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(tokens.radiusSm),
        ),
      ),
      dividerColor: BootstrapColors.border,
      extensions: [tokens],
    );
  }
}
