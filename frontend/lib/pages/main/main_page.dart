import 'dart:async';

import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/auth_service.dart';
import 'services/config_service.dart';
import 'services/llm_service.dart';
import 'services/slack_notification_service.dart';
import '../../services/session_service.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_select.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/bs/bs_text.dart';
import '../../widgets/page_help_box.dart';
import '../../widgets/status_footer.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  final _slackNoti = SlackNotificationService();
  final _llm = LlmService();
  final _config = ConfigService();
  final _auth = AuthService();
  final _focusNode = FocusNode();
  Timer? _idleTimer;
  Timer? _countdownTimer;
  DateTime? _lastSessionTouchedAt;
  bool _isSessionTouching = false;
  String _footerLabel = 'LLM - Chat';
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
    try {
      await _auth.logout();
    } catch (_) {
      // Keep local logout behavior even if server call fails.
    }
    SessionService.setUsername(null);
    SessionService.setAccessToken(null);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _sendInquiry() async {
    final controller = TextEditingController();
    final inquiry = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Inquiry'),
        content: TextField(
          controller: controller,
          maxLines: 5,
          decoration: const InputDecoration(
            labelText: 'Message',
            hintText: 'Write your inquiry here',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Send'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (inquiry == null || inquiry.isEmpty) {
      return;
    }

    final userId = SessionService.getUsername() ?? 'unknown-user';
    final message = '[$userId] "$inquiry"';
    try {
      await _slackNoti.sendSlackMessage(message);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inquiry sent to Slack')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Inquiry failed: $e')),
      );
    }
  }

  Future<String> _queryLlm(String prompt, {String? model}) =>
      _llm.query(prompt, model: model);

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
    const topTabs = [
      Tab(text: 'LLM'),
      Tab(text: 'Archives'),
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
          length: topTabs.length,
          initialIndex: 0,
          child: Scaffold(
            appBar: AppBar(
              leadingWidth: 110,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton.icon(
                  onPressed: _sendInquiry,
                  icon: const Icon(Icons.support_agent, size: 18),
                  label: const Text('Inquiry'),
                ),
              ),
              bottom: TabBar(
                tabs: topTabs,
                onTap: (index) {
                  _updateFooterLabel(index == 0 ? 'LLM - Chat' : 'Archives - Archive-picture');
                },
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
                _LlmWorkspace(
                  onContextChanged: _updateFooterLabel,
                  onQuery: _queryLlm,
                ),
                _ArchiveWorkspace(
                  onContextChanged: _updateFooterLabel,
                ),
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

class _LlmWorkspace extends StatefulWidget {
  const _LlmWorkspace({
    required this.onContextChanged,
    required this.onQuery,
  });
  final ValueChanged<String> onContextChanged;
  final Future<String> Function(String prompt, {String? model}) onQuery;

  @override
  State<_LlmWorkspace> createState() => _LlmWorkspaceState();
}

class _LlmWorkspaceState extends State<_LlmWorkspace> {
  static const _tabs = ['Chat'];
  static const _geminiModels = [
    _GeminiModelOption(label: 'Latest Flash', value: 'gemini-flash-latest'),
    _GeminiModelOption(label: 'Latest Pro', value: 'gemini-pro-latest'),
  ];
  final _promptController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isSending = false;
  final List<_ChatMessage> _messages = [];
  int _selectedIndex = 0;
  _GeminiModelOption _selectedModel = _geminiModels[0];

  @override
  void initState() {
    super.initState();
    widget.onContextChanged('LLM - ${_tabs[_selectedIndex]}');
  }

  @override
  void dispose() {
    _promptController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send() async {
    final prompt = _promptController.text.trim();
    if (prompt.isEmpty || _isSending) {
      return;
    }
    setState(() {
      _isSending = true;
      _messages.add(_ChatMessage(role: 'user', text: prompt));
      _promptController.clear();
    });
    _scrollToBottom();
    try {
      final output = await widget.onQuery(
        prompt,
        model: _selectedModel.value,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: output));
      });
      _scrollToBottom();
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _messages.add(_ChatMessage(role: 'assistant', text: 'LLM failed: $e'));
      });
      _scrollToBottom();
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _TwoPaneLayout(
      leftWidth: 220,
      left: BsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BsText('LLM', variant: BsTextVariant.subtitle),
            const SizedBox(height: 8),
            for (var i = 0; i < _tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BsButton(
                  onPressed: () {
                    setState(() => _selectedIndex = i);
                    widget.onContextChanged('LLM - ${_tabs[_selectedIndex]}');
                  },
                  label: _tabs[i],
                  fullWidth: true,
                  outline: i != _selectedIndex,
                ),
              ),
          ],
        ),
      ),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          BsCard(
            child: BsSelect<_GeminiModelOption>(
              label: 'Model',
              value: _selectedModel,
              items: _geminiModels
                  .map(
                    (model) => DropdownMenuItem<_GeminiModelOption>(
                      value: model,
                      child: Text(model.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) {
                  return;
                }
                setState(() => _selectedModel = value);
              },
            ),
          ),
          const SizedBox(height: 16),
          BsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const BsText('Chat', variant: BsTextVariant.subtitle),
                const SizedBox(height: 8),
                Container(
                  height: 360,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _messages.isEmpty
                      ? const Center(
                          child: BsText(
                            'Start chatting with a prompt.',
                            variant: BsTextVariant.muted,
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isUser = message.role == 'user';
                            return Align(
                              alignment: isUser
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 560),
                                margin: const EdgeInsets.symmetric(vertical: 4),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: isUser
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  message.text,
                                  style: TextStyle(
                                    color: isUser
                                        ? Theme.of(context).colorScheme.onPrimary
                                        : Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 12),
                BsTextField(
                  controller: _promptController,
                  label: 'Prompt',
                  maxLines: 3,
                ),
                const SizedBox(height: 12),
                BsButton(
                  onPressed: _isSending ? null : _send,
                  label: _isSending ? 'Sending...' : 'Send',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});
  final String role;
  final String text;
}

class _GeminiModelOption {
  const _GeminiModelOption({required this.label, required this.value});
  final String label;
  final String value;
}

class _ArchiveWorkspace extends StatefulWidget {
  const _ArchiveWorkspace({
    required this.onContextChanged,
  });
  final ValueChanged<String> onContextChanged;

  @override
  State<_ArchiveWorkspace> createState() => _ArchiveWorkspaceState();
}

class _ArchiveWorkspaceState extends State<_ArchiveWorkspace> {
  static const _archives = [
    'Archive-picture',
    'Archive-video',
    'Archive-Timbre',
    'Archive-Prosody',
    'Archive-emotion',
    'Archive-Natural Speech',
    'Archive-Diary',
  ];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.onContextChanged('Feature Test - ${_archives[_selectedIndex]}');
  }

  @override
  Widget build(BuildContext context) {
    return _TwoPaneLayout(
      leftWidth: 230,
      left: BsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BsText('Feature Archives', variant: BsTextVariant.subtitle),
            const SizedBox(height: 8),
            for (var i = 0; i < _archives.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BsButton(
                  onPressed: () {
                    setState(() => _selectedIndex = i);
                    widget.onContextChanged(
                      'Archives - ${_archives[_selectedIndex]}',
                    );
                  },
                  label: _archives[i],
                  fullWidth: true,
                  outline: i != _selectedIndex,
                ),
              ),
          ],
        ),
      ),
      right: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const PageHelpBox(
            message: 'Browse archive categories from the left sub tabs.',
          ),
          const SizedBox(height: 16),
          BsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BsText('Selected Archive', variant: BsTextVariant.subtitle),
                const SizedBox(height: 8),
                BsText(_archives[_selectedIndex]),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TwoPaneLayout extends StatelessWidget {
  const _TwoPaneLayout({
    required this.left,
    required this.right,
    required this.leftWidth,
  });

  final Widget left;
  final Widget right;
  final double leftWidth;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 900;
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: isNarrow
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        left,
                        const SizedBox(height: 16),
                        right,
                      ],
                    )
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SizedBox(width: leftWidth, child: left),
                        const SizedBox(width: 16),
                        Expanded(child: right),
                      ],
                    ),
            ),
          ),
        );
      },
    );
  }
}
