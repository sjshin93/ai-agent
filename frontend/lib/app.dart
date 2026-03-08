import 'package:flutter/material.dart';

import 'routes.dart';
import 'ui/bootstrap_theme.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MongMind',
      theme: BootstrapTheme.light(),
      initialRoute: AppRoutes.login,
      routes: AppRoutes.build(),
      debugShowCheckedModeBanner: false,
    );
  }
}
