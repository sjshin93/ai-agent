import 'session_store_io.dart'
    if (dart.library.html) 'session_store_web.dart';

class SessionService {
  static final SessionStore _store = SessionStore();

  static String? getUsername() => _store.getUsername();

  static void setUsername(String? value) => _store.setUsername(value);

  static String? getAccessToken() => _store.getAccessToken();

  static void setAccessToken(String? value) => _store.setAccessToken(value);

  static String? getApiTestLogs() => _store.getApiTestLogs();

  static void setApiTestLogs(String? value) => _store.setApiTestLogs(value);

  static String? getApiTestLogsFilename() => _store.getApiTestLogsFilename();

  static void setApiTestLogsFilename(String? value) =>
      _store.setApiTestLogsFilename(value);

  static bool getApiTestLogsEnabled() => _store.getApiTestLogsEnabled();

  static void setApiTestLogsEnabled(bool value) =>
      _store.setApiTestLogsEnabled(value);
}
