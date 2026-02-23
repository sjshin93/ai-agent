// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

class SessionStore {
  static const _key = 'username';
  static const _tokenKey = 'access_token';
  static const _djTokenKey = 'dj_access_token';
  static const _logsKey = 'api_test_logs';
  static const _logsFilenameKey = 'api_test_logs_filename';
  static const _logsEnabledKey = 'api_test_logs_enabled';

  String? getUsername() => html.window.localStorage[_key];

  void setUsername(String? value) {
    if (value == null || value.isEmpty) {
      html.window.localStorage.remove(_key);
      return;
    }
    html.window.localStorage[_key] = value;
  }

  String? getAccessToken() => html.window.localStorage[_tokenKey];

  void setAccessToken(String? value) {
    if (value == null || value.isEmpty) {
      html.window.localStorage.remove(_tokenKey);
      return;
    }
    html.window.localStorage[_tokenKey] = value;
  }

  String? getDjAccessToken() => html.window.localStorage[_djTokenKey];

  void setDjAccessToken(String? value) {
    if (value == null || value.isEmpty) {
      html.window.localStorage.remove(_djTokenKey);
      return;
    }
    html.window.localStorage[_djTokenKey] = value;
  }

  String? getApiTestLogs() => html.window.localStorage[_logsKey];

  void setApiTestLogs(String? value) {
    if (value == null || value.isEmpty) {
      html.window.localStorage.remove(_logsKey);
      return;
    }
    html.window.localStorage[_logsKey] = value;
  }

  String? getApiTestLogsFilename() => html.window.localStorage[_logsFilenameKey];

  void setApiTestLogsFilename(String? value) {
    if (value == null || value.isEmpty) {
      html.window.localStorage.remove(_logsFilenameKey);
      return;
    }
    html.window.localStorage[_logsFilenameKey] = value;
  }

  bool getApiTestLogsEnabled() => html.window.localStorage[_logsEnabledKey] == 'true';

  void setApiTestLogsEnabled(bool value) {
    html.window.localStorage[_logsEnabledKey] = value ? 'true' : 'false';
  }
}
