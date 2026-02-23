import 'package:flutter/material.dart';

class BsTabs extends StatelessWidget {
  const BsTabs({
    super.key,
    required this.tabs,
    required this.views,
  });

  final List<Tab> tabs;
  final List<Widget> views;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: tabs.length,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TabBar(tabs: tabs),
          const SizedBox(height: 12),
          Expanded(
            child: TabBarView(children: views),
          ),
        ],
      ),
    );
  }
}
