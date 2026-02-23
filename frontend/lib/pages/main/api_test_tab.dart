import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import 'services/collection_service.dart';
import '../../services/session_service.dart';
import '../../ui/bootstrap_colors.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_select.dart';
import '../../widgets/bs/bs_switch.dart';
import '../../widgets/bs/bs_text.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/page_help_box.dart';

class ApiTestTab extends StatefulWidget {
  const ApiTestTab({super.key});

  @override
  State<ApiTestTab> createState() => _ApiTestTabState();
}

class _ApiTestTabState extends State<ApiTestTab> {
  final _client = CollectionService();
  final _bodyController = TextEditingController();
  bool _isLoading = true;
  bool _isSending = false;
  bool _verifySsl = false;
  bool _persistLogsEnabled = false;
  String? _error;
  List<CollectionItem> _items = [];
  CollectionItem? _selected;
  Map<String, TextEditingController> _paramControllers = {};
  CollectionExecuteResult? _response;
  final List<Map<String, dynamic>> _logEntries = [];

  @override
  void initState() {
    super.initState();
    _persistLogsEnabled = SessionService.getApiTestLogsEnabled();
    if (_persistLogsEnabled) {
      _restoreLogs();
    } else {
      SessionService.setApiTestLogs(null);
      SessionService.setApiTestLogsFilename(null);
    }
    _loadItems();
  }

  @override
  void dispose() {
    _bodyController.dispose();
    for (final controller in _paramControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _restoreLogs() {
    final raw = SessionService.getApiTestLogs();
    if (raw == null || raw.isEmpty) {
      return;
    }
    try {
      final data = jsonDecode(raw) as List<dynamic>;
      for (final entry in data) {
        if (entry is Map<String, dynamic>) {
          _logEntries.add(Map<String, dynamic>.from(entry));
        }
      }
    } catch (_) {
      // Ignore malformed cache.
    }
  }

  void _persistLogs() {
    if (!_persistLogsEnabled) {
      return;
    }
    final raw = jsonEncode(_logEntries);
    SessionService.setApiTestLogs(raw);
  }

  Future<void> _loadItems() async {
    try {
      final items = await _client.fetchItems();
      if (!mounted) {
        return;
      }
      setState(() {
        _items = items;
        _selected = items.isNotEmpty ? items.first : null;
        _rebuildParams();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to load collection: $e';
        _isLoading = false;
      });
    }
  }

  void _rebuildParams() {
    for (final controller in _paramControllers.values) {
      controller.dispose();
    }
    _paramControllers = {};
    final selected = _selected;
    if (selected == null) {
      _bodyController.text = '';
      return;
    }
    final accessToken = SessionService.getAccessToken();
    final queryDefaults = _extractQueryParamDefaults(selected.url);
    for (final param in _collectParams(selected)) {
      final controller = TextEditingController();
      if (param == 'access_token' && accessToken != null) {
        controller.text = accessToken;
      } else if (queryDefaults.containsKey(param)) {
        controller.text = queryDefaults[param] ?? '';
      }
      _paramControllers[param] = controller;
    }
    _bodyController.text = selected.body ?? '';
  }

  List<String> _collectParams(CollectionItem item) {
    final seen = <String>{};
    final ordered = <String>[];
    void add(String value) {
      if (value.isEmpty || seen.contains(value)) {
        return;
      }
      seen.add(value);
      ordered.add(value);
    }

    for (final param in item.params) {
      add(param);
    }
    for (final param in _extractTemplateParams(item.url)) {
      add(param);
    }
    for (final param in _extractQueryParams(item.url)) {
      add(param);
    }
    for (final param in _extractTemplateParams(item.body)) {
      add(param);
    }
    final needsFrameworkUrl =
        ordered.contains('bds-core-framework-url') ||
        item.url.contains('{{bds-core-framework-url}}') ||
        (item.body?.contains('{{bds-core-framework-url}}') ?? false);
    ordered.removeWhere((param) => param == 'bds-core-framework-url');
    if (needsFrameworkUrl && !ordered.contains('siteId')) {
      ordered.insert(0, 'siteId');
    }
    return ordered;
  }

  List<String> _extractTemplateParams(String? value) {
    if (value == null || value.isEmpty) {
      return const [];
    }
    final matches = RegExp(r'{{\s*([\w.-]+)\s*}}').allMatches(value);
    return matches.map((m) => m.group(1)!).toList();
  }

  List<String> _extractQueryParams(String? value) {
    if (value == null || value.isEmpty) {
      return const [];
    }
    final queryIndex = value.indexOf('?');
    if (queryIndex == -1 || queryIndex == value.length - 1) {
      return const [];
    }
    final query = value.substring(queryIndex + 1);
    final params = <String>[];
    for (final part in query.split('&')) {
      if (part.isEmpty) {
        continue;
      }
      final key = part.split('=').first.trim();
      if (key.isEmpty) {
        continue;
      }
      if (key.contains('{{') || key.contains('}}')) {
        continue;
      }
      params.add(key);
    }
    return params;
  }

  Map<String, String> _extractQueryParamDefaults(String? value) {
    if (value == null || value.isEmpty) {
      return const {};
    }
    final queryIndex = value.indexOf('?');
    if (queryIndex == -1 || queryIndex == value.length - 1) {
      return const {};
    }
    final query = value.substring(queryIndex + 1);
    final defaults = <String, String>{};
    for (final part in query.split('&')) {
      if (part.isEmpty) {
        continue;
      }
      final split = part.split('=');
      final key = split.first.trim();
      if (key.isEmpty) {
        continue;
      }
      if (key.contains('{{') || key.contains('}}')) {
        continue;
      }
      final rawValue = split.length > 1 ? split.sublist(1).join('=') : '';
      final valueText = rawValue.trim();
      if (valueText.isEmpty) {
        continue;
      }
      if (valueText.contains('{{') || valueText.contains('}}')) {
        continue;
      }
      defaults[key] = valueText;
    }
    return defaults;
  }

  Future<void> _send() async {
    final selected = _selected;
    if (selected == null) {
      return;
    }
    setState(() {
      _error = null;
      _response = null;
      _isSending = true;
    });
    final params = <String, String>{};
    _paramControllers.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        params[key] = value;
      }
    });
    int? siteId;
    final rawSiteId = params['siteId'];
    if (_paramControllers.containsKey('siteId') &&
        (rawSiteId == null || rawSiteId.isEmpty)) {
      setState(() {
        _error = 'siteId is required';
        _isSending = false;
      });
      return;
    }
    if (rawSiteId != null && rawSiteId.isNotEmpty) {
      siteId = int.tryParse(rawSiteId);
      if (siteId == null) {
        setState(() {
          _error = 'siteId must be an integer';
          _isSending = false;
        });
        return;
      }
    }
    try {
      final result = await _client.execute(
        id: selected.id,
        params: params,
        siteId: siteId,
        body: _bodyController.text.trim().isEmpty
            ? null
            : _bodyController.text,
        accessToken: SessionService.getAccessToken(),
        verifySsl: _verifySsl,
      );
      if (!mounted) {
        return;
      }
      _appendLog(selected, params, result);
      setState(() {
        _response = result;
        _isSending = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Request failed: $e';
        _isSending = false;
      });
    }
  }

  void _appendLog(
    CollectionItem item,
    Map<String, String> params,
    CollectionExecuteResult result,
  ) {
    final entry = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'id': item.id,
      'name': item.name,
      'method': item.method,
      'url': result.url,
      'params': params,
      'request_body': _bodyController.text.trim(),
      'status_code': result.statusCode,
      'response_body': _truncate(result.body),
    };
    _logEntries.add(entry);
    _persistLogs();
  }

  String _truncate(String value) {
    const max = 20000;
    if (value.length <= max) {
      return value;
    }
    return value.substring(0, max);
  }

  Future<void> _downloadLogs() async {
    if (_logEntries.isEmpty) {
      setState(() => _error = 'No log entries to export.');
      return;
    }
    final payload = jsonEncode(_logEntries);
    final filename = _buildLogFilename();
    SessionService.setApiTestLogsFilename(filename);

    if (kIsWeb) {
      final bytes = utf8.encode(payload);
      final blob = html.Blob([bytes]);
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)..download = filename;
      anchor.click();
      html.Url.revokeObjectUrl(url);
      return;
    }

    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(payload);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Saved to ${file.path}')),
    );
  }

  String _timestampForFile() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Map<String, String> _currentParams() {
    final params = <String, String>{};
    _paramControllers.forEach((key, controller) {
      final value = controller.text.trim();
      if (value.isNotEmpty) {
        params[key] = value;
      }
    });
    return params;
  }

  String _buildLogFilename() {
    final params = _currentParams();
    final siteId = params['siteId'] ?? 'site';
    final url = _selected?.url ?? 'collection';
    final collectionName = _collectionNameFromUrl(url);
    final ts = _timestampForFile();
    return '${siteId}_${collectionName}_$ts.json';
  }

  String _collectionNameFromUrl(String url) {
    var value = url.trim();
    final schemeIndex = value.indexOf('://');
    if (schemeIndex != -1) {
      final slash = value.indexOf('/', schemeIndex + 3);
      value = slash == -1 ? '' : value.substring(slash);
    } else {
      final varEnd = value.lastIndexOf('}}');
      if (varEnd != -1) {
        value = value.substring(varEnd + 2);
      }
    }
    final queryIndex = value.indexOf('?');
    if (queryIndex != -1) {
      value = value.substring(0, queryIndex);
    }
    value = value.trim();
    if (value.startsWith('/')) {
      value = value.substring(1);
    }
    if (value.isEmpty) {
      value = 'collection';
    }
    value = value.replaceAll(RegExp(r'[^A-Za-z0-9_\\-]+'), '_');
    value = value.replaceAll(RegExp(r'_+'), '_');
    return value;
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1000),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BsCard(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHelpBox(
                    message: '저장된 API 컬렉션을 호출해 요청/응답을 검증할 수 있는 페이지입니다.',
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const BsText(
                        'API Collection Test',
                        variant: BsTextVariant.title,
                      ),
                      BsButton(
                        onPressed: _downloadLogs,
                        label: 'Download logs',
                        outline: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_isLoading) const LinearProgressIndicator(minHeight: 2),
                  if (_isLoading) const SizedBox(height: 12),
                  BsSelect<CollectionItem>(
                    label: 'Request',
                    value: _selected,
                    items: _items
                        .map(
                          (item) => DropdownMenuItem(
                            value: item,
                            child: Text('${item.method} ${item.name}'),
                          ),
                        )
                        .toList(),
                    enabled: !_isLoading,
                    onChanged: (value) {
                      setState(() {
                        _selected = value;
                        _rebuildParams();
                      });
                    },
                  ),
                  if (_selected != null) ...[
                    const SizedBox(height: 8),
                    BsText(_selected!.url, variant: BsTextVariant.muted),
                  ],
                  const SizedBox(height: 12),
                  BsSwitch(
                    value: _verifySsl,
                    onChanged: (value) => setState(() => _verifySsl = value),
                    label: 'Verify SSL certificates',
                    subtitle: 'Turn off only for self-signed certificates',
                  ),
                  const SizedBox(height: 8),
                  BsSwitch(
                    value: _persistLogsEnabled,
                    onChanged: (value) {
                      setState(() => _persistLogsEnabled = value);
                      SessionService.setApiTestLogsEnabled(value);
                      if (!value) {
                        SessionService.setApiTestLogs(null);
                        SessionService.setApiTestLogsFilename(null);
                      } else {
                        _persistLogs();
                      }
                    },
                    label: 'Save logs in browser',
                    subtitle: 'Keeps logs after refresh (stored in local storage)',
                  ),
                  const SizedBox(height: 12),
                  if (_paramControllers.isNotEmpty)
                    const BsText('Parameters', variant: BsTextVariant.subtitle),
                  if (_paramControllers.isNotEmpty) const SizedBox(height: 8),
                  ..._paramControllers.entries.map(
                    (entry) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: BsTextField(
                        controller: entry.value,
                        label: entry.key,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const BsText('JSON Body', variant: BsTextVariant.subtitle),
                  const SizedBox(height: 8),
                  BsTextField(
                    controller: _bodyController,
                    maxLines: 8,
                    label: 'Request body (optional)',
                  ),
                  const SizedBox(height: 12),
                  if (_error != null)
                    BsAlert(
                      message: _error!,
                      variant: BsVariant.danger,
                    ),
                  const SizedBox(height: 12),
                  BsButton(
                    onPressed: _isSending ? null : _send,
                    label: _isSending ? 'Sending...' : 'Send',
                  ),
                  if (_response != null) ...[
                    const SizedBox(height: 16),
                    const BsText('Response', variant: BsTextVariant.subtitle),
                    const SizedBox(height: 8),
                    BsText('Status: ${_response!.statusCode}'),
                    BsText('URL: ${_response!.url}'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      constraints: const BoxConstraints(maxHeight: 300),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceVariant
                            .withOpacity(0.4),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(_response!.body),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
