import 'package:flutter/material.dart';

import 'pages/main/main_page.dart';
import 'pages/auth/login_page.dart';
import 'pages/settings/danji_settings_page.dart';
import 'pages/settings/llm_settings_page.dart';

class AppRoutes {
  static const login = '/login';
  static const main = '/main';
  static const llmSettings = '/settings/llm';
  static const danjiSettings = '/settings/danji';

  static Map<String, WidgetBuilder> build() {
    return {
      login: (_) => const LoginPage(),
      main: (_) => const MainPage(),
      llmSettings: (_) => const LlmSettingsPage(),
      danjiSettings: (_) => const DanjiSettingsPage(),
    };
  }
}
