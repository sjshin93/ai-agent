import 'dart:async';

import 'package:flutter/material.dart';

import '../../ui/bootstrap_tokens.dart';

class BsToast {
  static void show(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.of(context);
    if (overlay == null) {
      return;
    }

    late final OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _ToastView(
        message: message,
        onClose: () => entry.remove(),
      ),
    );

    overlay.insert(entry);
    Timer(duration, () {
      if (entry.mounted) {
        entry.remove();
      }
    });
  }
}

class _ToastView extends StatelessWidget {
  const _ToastView({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<BsTokens>();
    return Positioned(
      left: 16,
      right: 16,
      bottom: 24,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: tokens?.toastPadding ??
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(tokens?.toastOpacity ?? 0.8),
            borderRadius: BorderRadius.circular(tokens?.radiusMd ?? 8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Expanded(
                child: Text(
                  message,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              IconButton(
                onPressed: onClose,
                icon: const Icon(Icons.close, color: Colors.white),
                tooltip: 'Close',
              ),
            ],
          ),
        ),
      ),
    );
  }
}
