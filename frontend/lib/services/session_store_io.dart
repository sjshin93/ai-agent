class SessionStore {
  String? _username;
  String? _accessToken;
  String? _djAccessToken;
  String? _apiTestLogs;
  String? _apiTestLogsFilename;
  bool _apiTestLogsEnabled = false;

  String? getUsername() => _username;

  void setUsername(String? value) {
    _username = value;
  }

  String? getAccessToken() => _accessToken;

  void setAccessToken(String? value) {
    _accessToken = value;
  }

  String? getDjAccessToken() => _djAccessToken;

  void setDjAccessToken(String? value) {
    _djAccessToken = value;
  }

  String? getApiTestLogs() => _apiTestLogs;

  void setApiTestLogs(String? value) {
    _apiTestLogs = value;
  }

  String? getApiTestLogsFilename() => _apiTestLogsFilename;

  void setApiTestLogsFilename(String? value) {
    _apiTestLogsFilename = value;
  }

  bool getApiTestLogsEnabled() => _apiTestLogsEnabled;

  void setApiTestLogsEnabled(bool value) {
    _apiTestLogsEnabled = value;
  }
}
