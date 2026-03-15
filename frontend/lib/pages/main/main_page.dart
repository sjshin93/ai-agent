import 'dart:async';
import 'dart:developer' as developer;
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/auth_service.dart';
import 'services/admin_service.dart';
import 'services/audio_recorder_service.dart';
import 'services/config_service.dart';
import 'services/diary_service.dart';
import 'services/llm_service.dart';
import 'services/slack_notification_service.dart';
import 'services/voice_archive_service.dart';
import 'services/voice_prompt_service.dart';
import 'api_test_tab.dart';
import '../../services/session_service.dart';
import '../../ui/bootstrap_colors.dart';
import '../../widgets/bs/bs_alert.dart';
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
  bool _isAdmin = SessionService.getUserRole() == 'admin';
  static const Duration _sessionTouchThrottle = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _loadIdleTimeout();
    unawaited(_refreshAuthProfile());
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
    SessionService.setUserRole(null);
    Navigator.of(context).pushNamedAndRemoveUntil(
      AppRoutes.login,
      (route) => false,
    );
  }

  Future<void> _refreshAuthProfile() async {
    try {
      final me = await _auth.me();
      if (!me.authenticated) {
        SessionService.setUserRole(null);
        if (_isAdmin && mounted) {
          setState(() => _isAdmin = false);
        }
        return;
      }
      if (!mounted) {
        return;
      }
      final role = (me.role ?? 'user').toLowerCase();
      SessionService.setUserRole(role);
      if (_isAdmin != (role == 'admin')) {
        setState(() => _isAdmin = role == 'admin');
      }
    } catch (_) {
      // Keep existing local role on temporary network failures.
    }
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

  List<Tab> _topTabs() {
    final tabs = <Tab>[
      const Tab(text: 'LLM'),
      const Tab(text: 'Archives'),
    ];
    if (_isAdmin) {
      tabs.add(const Tab(text: 'Admin'));
    }
    return tabs;
  }

  String _tabFooterLabel(int index) {
    if (index == 0) {
      return 'LLM - Chat';
    }
    if (index == 1) {
      return 'Archives - Archive-picture';
    }
    return 'Admin - Users';
  }

  @override
  Widget build(BuildContext context) {
    final topTabs = _topTabs();

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
                  _updateFooterLabel(_tabFooterLabel(index));
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
                if (_isAdmin)
                  _AdminWorkspace(
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
    final selected = _archives[_selectedIndex];
    final isDiaryTab = selected == 'Archive-Diary';
    final voiceCategory = _voiceCategoryFromLabel(selected);
    final helpMessage = isDiaryTab
        ? 'Diary entries follow the template provided on the left and are stored as raw text under /archive/{person_id}/memory/raw/.'
        : voiceCategory != null
            ? 'Load prompt direction and script from CSV, then record and review each item.'
            : 'Browse archive categories from the left sub tabs.';
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
          PageHelpBox(message: helpMessage),
          const SizedBox(height: 16),
          if (isDiaryTab)
            _ArchiveDiaryPane(onContextChanged: widget.onContextChanged)
          else if (voiceCategory != null)
            _ArchiveVoicePane(
              category: voiceCategory,
              title: selected,
            )
          else
            BsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const BsText('Selected Archive',
                      variant: BsTextVariant.subtitle),
                  const SizedBox(height: 8),
                  BsText(_archives[_selectedIndex]),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String? _voiceCategoryFromLabel(String label) {
    final normalized = label.trim().toLowerCase().replaceAll(' ', '');
    if (normalized.contains('timbre')) {
      return 'timbre';
    }
    if (normalized.contains('prosody')) {
      return 'prosody';
    }
    if (normalized.contains('emotion')) {
      return 'emotion';
    }
    return null;
  }
}

class _ArchiveVoicePane extends StatefulWidget {
  const _ArchiveVoicePane({
    required this.category,
    required this.title,
  });

  final String category;
  final String title;

  @override
  State<_ArchiveVoicePane> createState() => _ArchiveVoicePaneState();
}

class _ArchiveVoicePaneState extends State<_ArchiveVoicePane> {
  final _promptService = const VoicePromptService();
  final _archiveService = const VoiceArchiveService();
  final _recorder = createAudioRecorderService();
  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;
  String? _statusMessage;
  List<VoicePromptItem> _items = [];
  int _index = 0;
  RecordedAudio? _lastRecording;
  DateTime? _capturedAt;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _ArchiveVoicePane oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.category != widget.category) {
      _index = 0;
      _lastRecording = null;
      _capturedAt = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final response = await _promptService.fetchByCategory(widget.category);
      if (!mounted) {
        return;
      }
      setState(() {
        _items = response.items;
        _isLoading = false;
        _index = 0;
        _statusMessage = null;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  Future<void> _handleRecordOrSave() async {
    if (_isSaving) {
      developer.log(
        'ignored record/save click while saving',
        name: 'voice_archive_ui',
      );
      return;
    }
    if (!_recorder.isRecording) {
      try {
        developer.log(
          'record start requested category=${widget.category}',
          name: 'voice_archive_ui',
        );
        await _recorder.start();
        if (!mounted) {
          return;
        }
        setState(() {
          _capturedAt = DateTime.now();
          _statusMessage = '녹음 중입니다. 저장 버튼을 눌러 업로드하세요.';
        });
      } catch (e) {
        developer.log(
          'record start failed category=${widget.category}: $e',
          name: 'voice_archive_ui',
          level: 1000,
        );
        if (!mounted) {
          return;
        }
        setState(() => _statusMessage = '녹음을 시작하지 못했습니다: $e');
      }
      return;
    }

    setState(() => _isSaving = true);
    try {
      developer.log(
        'record stop requested category=${widget.category}',
        name: 'voice_archive_ui',
      );
      final recorded = await _recorder.stop();
      if (!mounted) {
        return;
      }
      developer.log(
        'record stop completed bytes=${recorded.bytes.length} mimeType=${recorded.mimeType} fileExt=${recorded.fileExt}',
        name: 'voice_archive_ui',
      );
      if (recorded.bytes.isEmpty) {
        developer.log(
          'upload skipped: recorded bytes are empty',
          name: 'voice_archive_ui',
          level: 1000,
        );
        setState(() {
          _statusMessage = '저장 실패: 녹음 데이터가 비어 있습니다. 잠시 더 녹음 후 다시 시도해주세요.';
        });
        return;
      }
      _lastRecording = recorded;
      final item = _items[_index];
      developer.log(
        'upload start category=${widget.category} promptId=${item.id}',
        name: 'voice_archive_ui',
      );
      final response = await _archiveService.upload(
        bytes: recorded.bytes,
        fileExt: recorded.fileExt,
        tags: widget.category,
        emotion: item.emotionLevel,
        referenceText: item.text,
        sttText: null,
        capturedAt: _capturedAt,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = '저장 완료: ${response.storageKey}';
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = '저장 실패: $e');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _handlePlay() async {
    final recorded = _lastRecording;
    if (recorded == null) {
      setState(() => _statusMessage = '먼저 녹음을 저장해 주세요.');
      return;
    }
    try {
      await _recorder.play(recorded);
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _statusMessage = '재생 실패: $e');
    }
  }

  void _move(int delta) {
    if (_items.isEmpty) {
      return;
    }
    final next = (_index + delta).clamp(0, _items.length - 1);
    if (next == _index) {
      return;
    }
    setState(() {
      _index = next;
      _statusMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const BsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LinearProgressIndicator(minHeight: 2),
            SizedBox(height: 12),
            BsText('Loading prompts...', variant: BsTextVariant.muted),
          ],
        ),
      );
    }
    if (_error != null) {
      return BsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            BsAlert(
              message: _error!,
              variant: BsVariant.danger,
            ),
            const SizedBox(height: 12),
            BsButton(
              onPressed: _load,
              label: 'Retry',
              outline: true,
            ),
          ],
        ),
      );
    }
    if (_items.isEmpty) {
      return const BsCard(
        child: BsText('No prompts found in CSV.', variant: BsTextVariant.muted),
      );
    }

    final item = _items[_index];
    final hasEmotionMeta = (item.emotionLevel?.isNotEmpty ?? false) ||
        (item.emotionIntensity?.isNotEmpty ?? false);
    final progressLabel = '${_index + 1} / ${_items.length}';

    return BsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              BsText(widget.title, variant: BsTextVariant.subtitle),
              BsText(progressLabel, variant: BsTextVariant.caption),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.45),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: Theme.of(context).dividerColor.withOpacity(0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BsText('녹음 가이드', variant: BsTextVariant.caption),
                const SizedBox(height: 6),
                Text(item.direction),
              ],
            ),
          ),
          if (hasEmotionMeta) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (item.emotionLevel != null)
                  _MetaChip(label: '감정', value: item.emotionLevel!),
                if (item.emotionIntensity != null)
                  _MetaChip(label: '단계', value: item.emotionIntensity!),
              ],
            ),
          ],
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.35),
              borderRadius: BorderRadius.circular(10),
            ),
            child: SelectableText(
              item.text,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BsButton(
                  onPressed: _isSaving ? null : _handleRecordOrSave,
                  label: _isSaving
                      ? '저장 중...'
                      : _recorder.isRecording
                          ? '저장'
                          : '녹음',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BsButton(
                  onPressed: _handlePlay,
                  label: '듣기',
                  outline: true,
                ),
              ),
            ],
          ),
          if (_statusMessage != null) ...[
            const SizedBox(height: 12),
            BsAlert(
              message: _statusMessage!,
              variant: _statusMessage!.startsWith('저장 완료')
                  ? BsVariant.success
                  : BsVariant.info,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: BsButton(
                  onPressed: _index > 0 ? () => _move(-1) : null,
                  label: '이전',
                  outline: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: BsButton(
                  onPressed: _index < _items.length - 1 ? () => _move(1) : null,
                  label: '다음',
                  outline: true,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetaChip extends StatelessWidget {
  const _MetaChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.25),
        ),
      ),
      child: Text(
        '$label: $value',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AdminWorkspace extends StatefulWidget {
  const _AdminWorkspace({
    required this.onContextChanged,
  });

  final ValueChanged<String> onContextChanged;

  @override
  State<_AdminWorkspace> createState() => _AdminWorkspaceState();
}

class _AdminWorkspaceState extends State<_AdminWorkspace> {
  static const _tabs = [
    'Logs',
    'Dashboard',
    'Users',
    'API Test',
  ];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    widget.onContextChanged('Admin - ${_tabs[_selectedIndex]}');
  }

  void _selectTab(int index) {
    if (_selectedIndex == index) {
      return;
    }
    final label = _tabs[index];
    setState(() => _selectedIndex = index);
    widget.onContextChanged('Admin - $label');
  }

  @override
  Widget build(BuildContext context) {
    return _TwoPaneLayout(
      leftWidth: 220,
      left: BsCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const BsText('Admin', variant: BsTextVariant.subtitle),
            const SizedBox(height: 8),
            for (var i = 0; i < _tabs.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: BsButton(
                  onPressed: () => _selectTab(i),
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
          if (_selectedIndex == 0) const _AdminLogsPane(),
          if (_selectedIndex == 1) const _AdminStatsPane(),
          if (_selectedIndex == 2) const _AdminUsersPane(),
          if (_selectedIndex == 3) const ApiTestTab(),
        ],
      ),
    );
  }
}

class _ArchiveDiaryPane extends StatefulWidget {
  const _ArchiveDiaryPane({
    required this.onContextChanged,
  });

  final ValueChanged<String> onContextChanged;

  @override
  State<_ArchiveDiaryPane> createState() => _ArchiveDiaryPaneState();
}

class _ArchiveDiaryPaneState extends State<_ArchiveDiaryPane> {
  static const _emotionLabels = [
    'joy',
    'happy',
    'excited',
    'grateful',
    'calm',
    'hopeful',
    'proud',
    'loved',
    'sad',
    'lonely',
    'disappointed',
    'regretful',
    'ashamed',
    'angry',
    'frustrated',
    'annoyed',
    'anxious',
    'afraid',
    'stressed',
    'confused',
  ];

  final _diaryService = const DiaryService();
  final _eventController = TextEditingController();
  final _feelingController = TextEditingController();
  final _reasonController = TextEditingController();
  final _nextActionController = TextEditingController();
  DateTime _eventDate = DateTime.now();
  String? _emotionLabel;
  bool _isSubmitting = false;
  String? _statusMessage;
  BsVariant _statusVariant = BsVariant.info;
  DiaryArchiveResponse? _response;

  @override
  void dispose() {
    _eventController.dispose();
    _feelingController.dispose();
    _reasonController.dispose();
    _nextActionController.dispose();
    super.dispose();
  }

  void _handleDateTap() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _eventDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _eventDate = picked);
    }
  }

  String _formatDate(DateTime value) {
    final year = value.year.toString().padLeft(4, '0');
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  String _formatTimestamp(DateTime value) {
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${_formatDate(local)} $hour:$minute';
  }

  String _buildRawText({
    required String eventText,
    required String feelingText,
    required String reasonText,
    required String nextActionText,
  }) {
    return [
      '<일기>',
      '날짜:${_formatDate(_eventDate)}',
      '대표감정:${_emotionLabel ?? ''}',
      '있었던 일:$eventText',
      '느낀 감정:$feelingText',
      '그 이유:$reasonText',
      '앞으로 어떻게 하고 싶은지:$nextActionText',
    ].join('\n');
  }

  Future<void> _submit() async {
    final eventText = _eventController.text.trim();
    final feelingText = _feelingController.text.trim();
    final reasonText = _reasonController.text.trim();
    final nextActionText = _nextActionController.text.trim();
    final rawText = _buildRawText(
      eventText: eventText,
      feelingText: feelingText,
      reasonText: reasonText,
      nextActionText: nextActionText,
    );
    setState(() {
      _isSubmitting = true;
      _statusMessage = null;
    });
    try {
      final result = await _diaryService.archiveDiary(
        eventDate: _eventDate,
        rawText: rawText,
        emotionLabel: _emotionLabel,
        eventText: eventText.isEmpty ? null : eventText,
        feelingText: feelingText.isEmpty ? null : feelingText,
        reasonText: reasonText.isEmpty ? null : reasonText,
        nextActionText: nextActionText.isEmpty ? null : nextActionText,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _response = result;
        _statusMessage = 'Diary saved (${_formatDate(result.eventDate)})';
        _statusVariant = BsVariant.success;
      });
      widget.onContextChanged(
        'Archives - Archive-Diary saved ${_formatDate(result.eventDate)}',
      );
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _statusMessage = 'Failed to archive diary: ${error.toString()}';
        _statusVariant = BsVariant.danger;
      });
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final eventText = _eventController.text.trim();
    final feelingText = _feelingController.text.trim();
    final reasonText = _reasonController.text.trim();
    final nextActionText = _nextActionController.text.trim();
    final rawPreview = _buildRawText(
      eventText: eventText,
      feelingText: feelingText,
      reasonText: reasonText,
      nextActionText: nextActionText,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        BsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const BsText('Archive-diary', variant: BsTextVariant.subtitle),
              const SizedBox(height: 8),
              Row(
                children: [
                  const BsText('날짜', variant: BsTextVariant.body),
                  const SizedBox(width: 12),
                  Expanded(
                    child: BsButton(
                      onPressed: _handleDateTap,
                      label: _formatDate(_eventDate),
                      outline: true,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BsSelect<String?>(
                label: '대표감정 (선택)',
                value: _emotionLabel,
                onChanged: (value) => setState(() => _emotionLabel = value),
                helperText: 'Optional emotion tag for this entry',
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('선택하지 않음'),
                  ),
                  ..._emotionLabels.map(
                    (label) => DropdownMenuItem<String?>(
                      value: label,
                      child: Text(label),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BsTextField(
                label: '있었던 일',
                controller: _eventController,
                maxLines: 3,
                helperText: '오늘 무엇이 있었는지 간단하게 작성하세요.',
              ),
              const SizedBox(height: 12),
              BsTextField(
                label: '느낀 감정',
                controller: _feelingController,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              BsTextField(
                label: '그 이유',
                controller: _reasonController,
                maxLines: 3,
              ),
              const SizedBox(height: 12),
              BsTextField(
                label: '앞으로 어떻게 하고 싶은지',
                controller: _nextActionController,
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              BsButton(
                onPressed: _isSubmitting ? null : _submit,
                label: _isSubmitting ? 'Archiving...' : 'Archive diary',
                fullWidth: true,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        BsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BsText('Raw preview', variant: BsTextVariant.subtitle),
              const SizedBox(height: 8),
              SelectableText(
                rawPreview,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
        if (_statusMessage != null) ...[
          const SizedBox(height: 12),
          BsAlert(
            message: _statusMessage!,
            variant: _statusVariant,
          ),
        ],
        if (_response != null) ...[
          const SizedBox(height: 12),
          BsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const BsText('Last archive', variant: BsTextVariant.subtitle),
                const SizedBox(height: 8),
                Text('ID: ${_response!.id}', style: Theme.of(context).textTheme.bodySmall),
                Text(
                  'Event date: ${_formatDate(_response!.eventDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'Stored at: ${_response!.storagePath}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  'SHA256: ${_response!.sha256}',
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Created at: ${_formatTimestamp(_response!.createdAt)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _AdminLogsPane extends StatefulWidget {
  const _AdminLogsPane();

  @override
  State<_AdminLogsPane> createState() => _AdminLogsPaneState();
}

class _AdminLogsPaneState extends State<_AdminLogsPane> {
  static const _logTypeLabels = {
    'system': 'System',
    'api': 'API',
    'error': 'Error',
  };

  final _admin = AdminService();
  bool _isLoading = true;
  String _logType = 'system';
  String? _error;
  List<AdminLogEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final entries = await _admin.fetchLogs(_logType);
      if (!mounted) {
        return;
      }
      setState(() {
        _entries = entries;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _setLogType(String type) {
    if (_logType == type) {
      return;
    }
    setState(() => _logType = type);
    _loadLogs();
  }

  String _formatTimestamp(DateTime time) {
    final local = time.toLocal();
    final year = local.year.toString().padLeft(4, '0');
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    final second = local.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }

  @override
  Widget build(BuildContext context) {
    return BsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BsText('Logs', variant: BsTextVariant.subtitle),
              BsButton(
                onPressed: _isLoading ? null : _loadLogs,
                label: 'Refresh',
                outline: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: _logTypeLabels.entries.map((entry) {
              final isSelected = entry.key == _logType;
              return BsButton(
                onPressed: () => _setLogType(entry.key),
                label: entry.value,
                outline: !isSelected,
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ...[
            const SizedBox(height: 8),
            BsText(_error!, variant: BsTextVariant.muted),
          ],
          if (!_isLoading && _error == null && _entries.isEmpty) ...[
            const SizedBox(height: 8),
            const BsText('No log entries yet.', variant: BsTextVariant.muted),
          ],
          if (!_isLoading && _error == null && _entries.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 320,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _entries.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final entry = _entries[index];
                  final statusColor = entry.statusCode >= 500
                      ? Theme.of(context).colorScheme.error
                      : entry.statusCode >= 400
                          ? Theme.of(context)
                              .colorScheme
                              .error
                              .withOpacity(0.75)
                          : Theme.of(context).colorScheme.primary;
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Text(
                      _formatTimestamp(entry.occurredAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    title: Text(
                      '${entry.method} ${entry.path}',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      'User: ${entry.userId.isEmpty ? 'anonymous' : entry.userId} • '
                      'IP: ${entry.clientIp}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          entry.statusCode.toString(),
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(color: statusColor),
                        ),
                        Text(
                          '${entry.durationMs} ms',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AdminStatsPane extends StatefulWidget {
  const _AdminStatsPane();

  @override
  State<_AdminStatsPane> createState() => _AdminStatsPaneState();
}

class _AdminStatsPaneState extends State<_AdminStatsPane> {
  final _admin = AdminService();
  bool _isLoading = true;
  String? _error;
  AdminStats? _stats;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final stats = await _admin.fetchStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BsText('Dashboard', variant: BsTextVariant.subtitle),
              BsButton(
                onPressed: _isLoading ? null : _loadStats,
                label: 'Refresh',
                outline: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ...[
            const SizedBox(height: 8),
            BsText(_error!, variant: BsTextVariant.muted),
          ],
          if (_stats != null) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _MetricBadge(
                  label: '가입자 수',
                  value: _stats!.subscriberCount,
                ),
                _MetricBadge(
                  label: '접속자 수',
                  value: _stats!.visitorCount,
                ),
                _MetricBadge(
                  label: 'API 호출량',
                  value: _stats!.apiCallCount,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const BsText('Traffic (hourly)', variant: BsTextVariant.caption),
            const SizedBox(height: 12),
            _TrafficGraph(_stats!.traffic),
          ],
        ],
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  const _MetricBadge({
    required this.label,
    required this.value,
  });

  final String label;
  final int value;

  String get _formattedValue {
    final text = value.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (var i = text.length - 1; i >= 0; i--) {
      if (count == 3) {
        buffer.write(',');
        count = 0;
      }
      buffer.write(text[i]);
      count += 1;
    }
    return buffer.toString().split('').reversed.join();
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    final textColor = Theme.of(context).colorScheme.onSurface.withOpacity(0.7);
    return Container(
      constraints: const BoxConstraints(minWidth: 140),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formattedValue,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: textColor,
                ),
          ),
        ],
      ),
    );
  }
}

class _TrafficGraph extends StatelessWidget {
  const _TrafficGraph(this.traffic);

  final List<TrafficPoint> traffic;

  @override
  Widget build(BuildContext context) {
    if (traffic.isEmpty) {
      return const BsText('Traffic data unavailable.', variant: BsTextVariant.muted);
    }
    final maxCalls = traffic.fold<int>(
      0,
      (prev, element) => math.max(prev, element.apiCalls),
    );
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: traffic.map((point) {
          final ratio = maxCalls > 0 ? point.apiCalls / maxCalls : 0;
          final barHeight = (ratio * 120).clamp(8.0, 140.0).toDouble();
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    point.apiCalls.toString(),
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    height: barHeight,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _hourLabel(point.timestamp),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  static String _hourLabel(DateTime timestamp) {
    final local = timestamp.toLocal();
    return '${local.hour.toString().padLeft(2, '0')}:00';
  }
}

class _AdminUsersPane extends StatefulWidget {
  const _AdminUsersPane();

  @override
  State<_AdminUsersPane> createState() => _AdminUsersPaneState();
}

class _AdminUsersPaneState extends State<_AdminUsersPane> {
  final _admin = AdminService();
  bool _isLoading = true;
  String? _error;
  List<AdminUser> _users = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final users = await _admin.fetchUsers();
      if (!mounted) {
        return;
      }
      setState(() {
        _users = users;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = 'Failed to load users: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return BsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const BsText('Users', variant: BsTextVariant.subtitle),
              BsButton(
                onPressed: _isLoading ? null : _loadUsers,
                label: 'Refresh',
                outline: true,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_isLoading) const LinearProgressIndicator(minHeight: 2),
          if (_error != null) ...[
            const SizedBox(height: 8),
            BsText(_error!, variant: BsTextVariant.muted),
          ],
          if (!_isLoading && _error == null && _users.isEmpty) ...[
            const SizedBox(height: 8),
            const BsText('No users found.', variant: BsTextVariant.muted),
          ],
          if (!_isLoading && _error == null && _users.isNotEmpty) ...[
            const SizedBox(height: 12),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columns: const [
                  DataColumn(label: Text('ID')),
                  DataColumn(label: Text('nickname')),
                  DataColumn(label: Text('role')),
                ],
                rows: _users
                    .map(
                      (user) => DataRow(
                        cells: [
                          DataCell(Text(user.userId)),
                          DataCell(Text(user.nickname)),
                          DataCell(Text(user.role)),
                        ],
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
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
