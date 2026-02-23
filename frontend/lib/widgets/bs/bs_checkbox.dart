import 'package:flutter/material.dart';

class BsCheckbox extends StatelessWidget {
  const BsCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.subtitle,
    this.contentPadding,
  });

  final bool value;
  final ValueChanged<bool?>? onChanged;
  final String label;
  final String? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: value,
      onChanged: onChanged,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: contentPadding,
    );
  }
}
