import 'dart:async';

import 'package:flutter/material.dart';

import '../pages/main/services/config_service.dart';

class StatusFooter extends StatefulWidget {
  const StatusFooter({
    super.key,
    required this.contextLabel,
    required this.contextTimestamp,
  });

  final String contextLabel;
  final String contextTimestamp;

  @override
  State<StatusFooter> createState() => _StatusFooterState();
}

class _StatusFooterState extends State<StatusFooter> {
  Timer? _timer;
  late String _timestamp;
  final _config = ConfigService();
  String _version = '--';

  @override
  void initState() {
    super.initState();
    _timestamp = _formatTimestamp(DateTime.now());
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
    _loadVersion();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _tick() {
    if (!mounted) {
      return;
    }
    setState(() => _timestamp = _formatTimestamp(DateTime.now()));
  }

  Future<void> _loadVersion() async {
    final version = await _config.getVersion();
    if (!mounted) {
      return;
    }
    setState(() => _version = version);
  }

  String _formatTimestamp(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      elevation: 8,
      color: colorScheme.surface,
      child: SizedBox(
        height: 48,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 12),
            Text(_timestamp),
            const Spacer(),
            Text('Version: $_version'),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }
}
