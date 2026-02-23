# UI Guide

This document provides a quick guide for using the UI components in:

- `frontend/lib/ui`
- `frontend/lib/widgets/bs`

## 1) Core Concepts

- Theme: `BootstrapTheme.light()` provides the base look and feel.
- Tokens: `BsTokens` centralizes spacing, radius, hover state, and UI details.
- Components: widgets under `widgets/bs` automatically follow the active theme and tokens.

## 2) Apply the Theme

Apply the theme in `frontend/lib/app.dart`.

## 3) Token Customization

When you change values in `frontend/lib/ui/bootstrap_tokens.dart`, the shared components update together.

## 4) Component List

See the `frontend/lib/widgets/bs` directory for the current set of components.

## 5) Usage Examples

Use English labels/messages in examples and product UI for consistency.

## 6) Notes

- Prefer token-based design adjustments through `BsTokens`.
- Avoid hard-coded visual styles directly in components when possible.
- If you want to use a custom font, add the font file and register it in `pubspec.yaml`.
