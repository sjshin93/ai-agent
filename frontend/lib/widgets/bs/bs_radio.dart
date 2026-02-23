import 'package:flutter/material.dart';

class BsRadio<T> extends StatelessWidget {
  const BsRadio({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.label,
    this.subtitle,
    this.contentPadding,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T?>? onChanged;
  final String label;
  final String? subtitle;
  final EdgeInsetsGeometry? contentPadding;

  @override
  Widget build(BuildContext context) {
    return RadioListTile<T>(
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      title: Text(label),
      subtitle: subtitle == null ? null : Text(subtitle!),
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: contentPadding,
    );
  }
}
