# Pages Structure Rules

## Basic Structure

- Put each feature screen and related logic under `pages/<feature>/`.
- Manage routing only in `lib/routes.dart`.

## Service Rules

- Place feature-specific services under `pages/<feature>/services/`.
- Use `*Service.dart` as the service file naming convention.
- A screen should directly reference only services from its own feature.

## State / ViewModel Rules

- Place per-screen state/view-model code under `pages/<feature>/state/`.
- Use one naming pattern consistently: `*State.dart` or `*ViewModel.dart`.
- A screen widget should directly reference only state/view-model classes from the same feature.
