import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import 'services/jira_service.dart';
import '../../services/session_service.dart';
import '../../ui/bootstrap_colors.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_select.dart';
import '../../widgets/bs/bs_text.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/page_help_box.dart';

class JiraFsCreateTab extends StatefulWidget {
  const JiraFsCreateTab({super.key, required this.client});

  final JiraService client;

  @override
  State<JiraFsCreateTab> createState() => _JiraFsCreateTabState();
}

class _JiraFsCreateTabState extends State<JiraFsCreateTab> {
  final _titleController = TextEditingController();
  final _problemController = TextEditingController();
  final _inspectionController = TextEditingController();
  bool _isSubmitting = false;
  bool _isLoadingOptions = true;
  String? _error;
  String? _fileError;
  List<String> _customerParts = [];
  List<String> _reqTypes = [];
  String? _selectedCustomerPart;
  String? _selectedReqType;
  final List<JiraAttachment> _attachments = [];

  static const String _defaultCustomerPart = 'etc';
  static const String _defaultReqType = '디버깅(점검)';

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _problemController.dispose();
    _inspectionController.dispose();
    super.dispose();
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
        _error = 'Failed to load options: $e';
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

  Future<void> _pickFiles() async {
    setState(() => _fileError = null);
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const [
        'log',
        'txt',
        'png',
        'jpg',
        'jpeg',
        'gif',
        'bmp',
        'mp4',
        'mov',
        'avi',
        'mkv',
        'webm',
        'json',
      ],
    );
    if (result == null) {
      return;
    }
    final selected = <JiraAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null) {
        _fileError = 'Unable to read file: ${file.name}';
        continue;
      }
      selected.add(
        JiraAttachment(
          name: file.name,
          bytes: bytes,
          size: file.size,
        ),
      );
    }
    if (!mounted) {
      return;
    }
    setState(() {
      _attachments.addAll(selected);
    });
  }

  void _removeAttachment(int index) {
    setState(() => _attachments.removeAt(index));
  }

  void _clearAttachments() {
    setState(() => _attachments.clear());
  }

  void _attachApiLogs() {
    final raw = SessionService.getApiTestLogs();
    if (raw == null || raw.isEmpty) {
      setState(() => _fileError = 'No API test logs to attach.');
      return;
    }
    final bytes = utf8.encode(raw);
    final name = SessionService.getApiTestLogsFilename() ??
        'api_test_logs_${_timestampForFile()}.json';
    setState(() {
      _attachments.add(
        JiraAttachment(
          name: name,
          bytes: bytes,
          size: bytes.length,
        ),
      );
    });
  }

  String _timestampForFile() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    final problem = _problemController.text.trim();
    final inspection = _inspectionController.text.trim();
    final desc = _buildDescription(problem: problem, inspection: inspection);
    final customerPart = _selectedCustomerPart;
    final reqType = _selectedReqType;
    if (title.isEmpty) {
      setState(() => _error = 'Please enter a title.');
      return;
    }
    if (problem.length < 10) {
      setState(() => _error = '문제 내용은 최소 10글자 이상 입력해주세요.');
      return;
    }
    if (inspection.length < 10) {
      setState(() => _error = '점검 내용은 최소 10글자 이상 입력해주세요.');
      return;
    }
    if (customerPart == null || customerPart.isEmpty) {
      setState(() => _error = 'Please select a customer part.');
      return;
    }
    if (reqType == null || reqType.isEmpty) {
      setState(() => _error = 'Please select a request type.');
      return;
    }
    setState(() {
      _error = null;
      _isSubmitting = true;
    });
    try {
      final result = await widget.client.createIssueWithAttachments(
        title: title,
        description: desc,
        customerPart: customerPart,
        reqType: reqType,
        attachments: _attachments,
      );
      if (!mounted) {
        return;
      }
      _titleController.clear();
      _problemController.clear();
      _inspectionController.clear();
      setState(() => _attachments.clear());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Jira created: ${result.key}'),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() => _error = 'Jira creation failed: $e');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    }
    final kb = bytes / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)}KB';
    }
    final mb = kb / 1024;
    if (mb < 1024) {
      return '${mb.toStringAsFixed(1)}MB';
    }
    final gb = mb / 1024;
    return '${gb.toStringAsFixed(2)}GB';
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
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 900),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BsCard(
            child: Padding(
              padding: const EdgeInsets.all(0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const PageHelpBox(
                    message: 'Jira FS 이슈 생성과 첨부 파일 업로드를 테스트할 수 있는 페이지입니다.',
                  ),
                  const SizedBox(height: 16),
                  const BsText(
                    'Jira FS Create',
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
                    onChanged: (value) =>
                        setState(() => _selectedCustomerPart = value),
                  ),
                  const SizedBox(height: 12),
                  BsSelect<String>(
                    label: 'Req Type',
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
                    onChanged: (value) =>
                        setState(() => _selectedReqType = value),
                  ),
                  const SizedBox(height: 12),
                  BsTextField(
                    controller: _titleController,
                    label: 'Title',
                  ),
                  const SizedBox(height: 12),
                  BsTextField(
                    controller: _problemController,
                    maxLines: 4,
                    label: '문제 내용',
                    helperText: '장애 시점, 민원 접수 시점/세대 동호 등',
                  ),
                  const SizedBox(height: 12),
                  BsTextField(
                    controller: _inspectionController,
                    maxLines: 4,
                    label: '점검 내용',
                    helperText: '물리/통신 점검 및 대응 내용, 재현 방법, 기타 확인 사항',
                  ),
                  const SizedBox(height: 12),
                  const BsText(
                    'Attachments (log/image/video)',
                    variant: BsTextVariant.subtitle,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      BsButton(
                        onPressed: _pickFiles,
                        label: 'Add files',
                      ),
                      BsButton(
                        onPressed: _attachApiLogs,
                        label: 'Attach API Test logs',
                        outline: true,
                      ),
                      BsButton(
                        onPressed:
                            _attachments.isEmpty ? null : _clearAttachments,
                        label: 'Clear all',
                        outline: true,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_fileError != null)
                    BsAlert(
                      message: _fileError!,
                      variant: BsVariant.danger,
                    ),
                  if (_attachments.isEmpty)
                    const BsText('No files selected', variant: BsTextVariant.muted),
                  if (_attachments.isNotEmpty)
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _attachments.length,
                      separatorBuilder: (_, __) => const Divider(height: 8),
                      itemBuilder: (context, index) {
                        final file = _attachments[index];
                        return Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${file.name} (${_formatBytes(file.size)})',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              onPressed: () => _removeAttachment(index),
                              icon: const Icon(Icons.close),
                              tooltip: 'Remove',
                            ),
                          ],
                        );
                      },
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
                    label: _isSubmitting ? 'Creating...' : 'Create Jira',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
