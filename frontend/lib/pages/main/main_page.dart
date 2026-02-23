import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes.dart';
import 'services/config_service.dart';
import 'services/jira_service.dart';
import 'services/llm_service.dart';
import 'services/slack_notification_service.dart';
import '../../services/session_service.dart';
import 'services/ssh_service.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_select.dart';
import '../../widgets/bs/bs_text.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/page_help_box.dart';
import '../../widgets/status_footer.dart';
import 'api_test_tab.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage>
    with SingleTickerProviderStateMixin {
  final _slackNoti = SlackNotificationService();
  final _ssh = SshService();
  final _llm = LlmService();
  final _config = ConfigService();
  final _focusNode = FocusNode();
  Timer? _idleTimer;
  Timer? _countdownTimer;
  DateTime? _lastSessionTouchedAt;
  bool _isSessionTouching = false;
  String _footerLabel = '기능 ?�스??;
  String _footerTimestamp = _formatTimestamp(DateTime.now());
  Duration _idleTimeout = const Duration(minutes: 5);
  int _remainingSeconds = 300;
  static const Duration _sessionTouchThrottle = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _loadIdleTimeout();
  }

  @override
  void dispose() {
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _updateFooterLabel(String label) {
    setState(() {
      _footerLabel = label;
      _footerTimestamp = _formatTimestamp(DateTime.now());
    });
  }

  Future<void> _loadIdleTimeout() async {
    final seconds = await _config.getAutoLogoutSeconds();
    if (!mounted) {
      return;
    }
    setState(() {
      _idleTimeout = Duration(seconds: seconds);
      _remainingSeconds = _idleTimeout.inSeconds;
    });
    _resetIdleTimer();
  }

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(_idleTimeout, _handleIdleTimeout);
    _remainingSeconds = _idleTimeout.inSeconds;
    _countdownTimer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _tickCountdown(),
    );
    unawaited(_touchSessionIfNeeded());
  }

  Future<void> _touchSessionIfNeeded() async {
    if (_isSessionTouching) {
      return;
    }
    final now = DateTime.now();
    final last = _lastSessionTouchedAt;
    if (last != null && now.difference(last) < _sessionTouchThrottle) {
      return;
    }

    _isSessionTouching = true;
    try {
      final ok = await _config.touchSession();
      if (!mounted) {
        return;
      }
      if (!ok) {
        _handleIdleTimeout();
        return;
      }
      _lastSessionTouchedAt = DateTime.now();
    } finally {
      _isSessionTouching = false;
    }
  }

  void _tickCountdown() {
    if (!mounted) {
      return;
    }
    if (_remainingSeconds <= 0) {
      return;
    }
    setState(() => _remainingSeconds -= 1);
  }

  void _handleIdleTimeout() {
    if (!mounted) {
      return;
    }
    _idleTimer?.cancel();
    _countdownTimer?.cancel();
    _logoutAndNavigate();
  }

  Future<void> _logoutAndNavigate() async {
    if (!mounted) {
      return;
    }
    SessionService.setUsername(null);
    SessionService.setAccessToken(null);
    SessionService.setDjAccessToken(null);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }


  Future<void> _sendSlackTest() async {
    try {
      await _slackNoti.sendSlackMessage('Hello Slack');
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Slack message sent')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Slack failed: $e')),
      );
    }
  }

  Future<void> _runLlmTest() async {
    final prompt = await _askPrompt();
    if (prompt == null || prompt.trim().isEmpty) {
      return;
    }
    try {
      final output = await _llm.query(prompt.trim());
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('LLM Response'),
          content: SingleChildScrollView(
            child: Text(output),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('LLM failed: $e')),
      );
    }
  }

  Future<void> _fetchSshCommand(String command) async {
    final siteId = await _askSiteId();
    if (siteId == null || siteId.trim().isEmpty) {
      return;
    }
    try {
      final username = SessionService.getUsername() ?? 'unknown';
      final output = await _ssh.fetchCommand(siteId.trim(), command, username);
      if (!mounted) {
        return;
      }
      await showDialog<void>(
        context: context,
        builder: (_) => AlertDialog(
          title: Text('$command (site $siteId)'),
          content: SingleChildScrollView(
            child: Text(output),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('SSH $command failed: $e')),
      );
    }
  }

  Future<String?> _askPrompt() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter prompt'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'prompt',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<String?> _askSiteId() async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Enter site ID'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'site_id (e.g. 8)',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  static String _formatTimestamp(DateTime time) {
    final y = time.year.toString().padLeft(4, '0');
    final m = time.month.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final hh = time.hour.toString().padLeft(2, '0');
    final mm = time.minute.toString().padLeft(2, '0');
    final ss = time.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  String _formatRemaining() {
    final minutes = (_remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const tabs = [
      Tab(text: 'Feature Test'),
      Tab(text: 'API Test'),
    ];
    return RawKeyboardListener(
      focusNode: _focusNode,
      autofocus: true,
      onKey: (_) => _resetIdleTimer(),
      child: Listener(
        onPointerDown: (_) => _resetIdleTimer(),
        onPointerMove: (_) => _resetIdleTimer(),
        onPointerSignal: (_) => _resetIdleTimer(),
        child: DefaultTabController(
          length: tabs.length,
          child: Scaffold(
            appBar: AppBar(
              bottom: TabBar(
                onTap: (index) {
                  final label = switch (index) {
                    0 => 'Feature Test',
                    1 => 'API Test',
                    _ => 'Unknown',
                  };
                  _updateFooterLabel(label);
                },
                tabs: tabs,
              ),
              actions: [
                Center(
                  child: Text(
                    _formatRemaining(),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _logoutAndNavigate,
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: TabBarView(
              children: [
                _StatusDashboard(
                  onLlmTest: _runLlmTest,
                  onSlackTest: _sendSlackTest,
                  onSshTop: () => _fetchSshCommand('top'),
                  onSshFree: () => _fetchSshCommand('free'),
                ),
                const ApiTestTab(),
              ],
            ),
            bottomNavigationBar: StatusFooter(
              contextLabel: _footerLabel,
              contextTimestamp: _footerTimestamp,
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusDashboard extends StatelessWidget {
  const _StatusDashboard({
    required this.onLlmTest,
    required this.onSlackTest,
    required this.onSshTop,
    required this.onSshFree,
  });
  final VoidCallback onLlmTest;
  final VoidCallback onSlackTest;
  final VoidCallback onSshTop;
  final VoidCallback onSshFree;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const PageHelpBox(
                message: '???�이지?�서 ?�공?�는 기능???�상 ?�작중인지 ?�인?????�는 ?�이지?�니??',
              ),
              const SizedBox(height: 16),
              const BsText(
                'Quick Actions',
                variant: BsTextVariant.title,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _StatusCard(
                    title: 'LLM Test',
                    value: 'Send prompt',
                    actionLabel: 'Run LLM',
                    onPressed: onLlmTest,
                  ),
                  _StatusCard(
                    title: 'Slack Notification',
                    value: 'Send test message',
                    actionLabel: 'Hello Slack',
                    onPressed: onSlackTest,
                  ),
                  _StatusCard(
                    title: 'Danji Server SSH',
                    value: 'Run top once',
                    actionLabel: 'Fetch top',
                    onPressed: onSshTop,
                  ),
                  _StatusCard(
                    title: 'Danji Server SSH',
                    value: 'Run free -m',
                    actionLabel: 'Fetch free',
                    onPressed: onSshFree,
                  ),
                ],
              ),
              // Jira issue panel removed from TEST PAGE.
            ],
          ),
        ),
      ),
    );
  }
}

class JiraIssuePanel extends StatefulWidget {
  const JiraIssuePanel({super.key, required this.client});

  final JiraService client;

  @override
  State<JiraIssuePanel> createState() => _JiraIssuePanelState();
}

class _JiraIssuePanelState extends State<JiraIssuePanel> {
  final _titleController = TextEditingController();
  final _problemController = TextEditingController();
  final _inspectionController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingOptions = true;
  String? _error;
  List<String> _customerParts = [];
  List<String> _reqTypes = [];
  String? _selectedCustomerPart;
  String? _selectedReqType;

  static const String _defaultCustomerPart = 'etc';
  static const String _defaultReqType = '?�버�??��?)';

  @override
  void dispose() {
    _titleController.dispose();
    _problemController.dispose();
    _inspectionController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  Future<void> _loadOptions() async {
    try {
      final options = await widget.client.fetchFieldOptions();
      if (!mounted) {
        return;
      }
      final customerParts = options.customerParts;
      final reqTypes = options.reqTypes;
      setState(() {
        _customerParts = customerParts;
        _reqTypes = reqTypes;
        _selectedCustomerPart =
            _pickDefault(customerParts, _defaultCustomerPart);
        _selectedReqType = _pickDefault(reqTypes, _defaultReqType);
        _isLoadingOptions = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '?�션 로딩 ?�패: $e';
        _isLoadingOptions = false;
      });
    }
  }

  String? _pickDefault(List<String> options, String preferred) {
    if (options.contains(preferred)) {
      return preferred;
    }
    if (options.isNotEmpty) {
      return options.first;
    }
    return null;
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final problem = _problemController.text.trim();
    final inspection = _inspectionController.text.trim();
    final desc = _buildDescription(problem: problem, inspection: inspection);
    final customerPart = _selectedCustomerPart;
    final reqType = _selectedReqType;
    if (title.isEmpty) {
      setState(() => _error = '?�목???�력?�주?�요.');
      return;
    }
    if (problem.length < 10) {
      setState(() => _error = '문제 ?�용?� 최소 10글???�상 ?�력?�주?�요.');
      return;
    }
    if (inspection.length < 10) {
      setState(() => _error = '?��? ?�용?� 최소 10글???�상 ?�력?�주?�요.');
      return;
    }
    if (customerPart == null || customerPart.isEmpty) {
      setState(() => _error = 'Customer Part�??�택?�주?�요.');
      return;
    }
    if (reqType == null || reqType.isEmpty) {
      setState(() => _error = 'ReqType???�택?�주?�요.');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      final result = await widget.client.createIssue(
        title: title,
        description: desc,
        customerPart: customerPart,
        reqType: reqType,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _problemController.clear();
      _inspectionController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jira ?�성 ?�료: ${result.key}'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Jira ?�성 ?�패: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _buildDescription({
    required String problem,
    required String inspection,
  }) {
    return [
      '[Problem]',
      problem,
      '',
      '[Inspection]',
      inspection,
    ].join('\n');
  }

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 900),
      child: BsCard(
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BsText(
                'Jira Task ?�성 (TS)',
                variant: BsTextVariant.title,
              ),
              const SizedBox(height: 16),
              if (_isLoadingOptions)
                const LinearProgressIndicator(minHeight: 2),
              if (_isLoadingOptions) const SizedBox(height: 12),
              BsSelect<String>(
                label: 'Customer Part',
                value: _selectedCustomerPart,
                items: _customerParts
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                enabled: !_isLoadingOptions,
                onChanged: (value) => setState(() => _selectedCustomerPart = value),
              ),
              const SizedBox(height: 12),
              BsSelect<String>(
                label: 'ReqType',
                value: _selectedReqType,
                items: _reqTypes
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item),
                      ),
                    )
                    .toList(),
                enabled: !_isLoadingOptions,
                onChanged: (value) => setState(() => _selectedReqType = value),
              ),
              const SizedBox(height: 12),
              BsTextField(
                controller: _titleController,
                label: '?�목',
              ),
              const SizedBox(height: 12),
              BsTextField(
                controller: _problemController,
                label: '문제 ?�용',
                maxLines: 4,
                helperText: '?�애 ?�점, 민원 ?�수 ?�점/?��? ?�호 ??,
              ),
              const SizedBox(height: 12),
              BsTextField(
                controller: _inspectionController,
                label: '?��? ?�용',
                maxLines: 4,
                helperText: '물리/?�신 ?��? �??�???�용, ?�현 방법, 기�? ?�인 ?�항',
              ),
              const SizedBox(height: 12),
              if (_error != null)
                BsAlert(
                  message: _error!,
                  variant: BsVariant.danger,
                ),
              const SizedBox(height: 12),
              BsButton(
                onPressed: _isSubmitting ? null : _submit,
                label: _isSubmitting ? '?�성 �?..' : 'Jira ?�성',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.title,
    required this.value,
    this.actionLabel,
    this.onPressed,
  });

  final String title;
  final String value;
  final String? actionLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: BsCard(
        child: Padding(
          padding: const EdgeInsets.all(0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              BsText(title, variant: BsTextVariant.subtitle),
              const SizedBox(height: 8),
              BsText(value),
              if (actionLabel != null && onPressed != null) ...[
                const SizedBox(height: 12),
                BsButton(onPressed: onPressed, label: actionLabel!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
