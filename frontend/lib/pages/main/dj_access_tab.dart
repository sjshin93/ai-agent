import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../services/session_service.dart';
import '../../ui/bootstrap_colors.dart';
import '../../widgets/bs/bs_alert.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text.dart';
import '../../widgets/bs/bs_text_field.dart';
import '../../widgets/page_help_box.dart';

class DjAccessTab extends StatefulWidget {
  const DjAccessTab({super.key});

  @override
  State<DjAccessTab> createState() => _DjAccessTabState();
}

class _DjAccessTabState extends State<DjAccessTab> {
  final _siteIdController = TextEditingController();
  final _dongController = TextEditingController();
  final _hoController = TextEditingController();
  String? _error;
  String? _result;
  bool _isSubmitting = false;
  bool _isRebooting = false;

  @override
  void dispose() {
    _siteIdController.dispose();
    _dongController.dispose();
    _hoController.dispose();
    super.dispose();
  }

  Future<void> _requestHouseholdAccess() async {
    setState(() {
      _error = null;
      _result = null;
      _isSubmitting = true;
    });

    final siteId = _siteIdController.text.trim();
    final dong = _dongController.text.trim();
    final ho = _hoController.text.trim();
    final username = SessionService.getUsername();
    final token = SessionService.getDjAccessToken();

    if (siteId.isEmpty || dong.isEmpty || ho.isEmpty) {
      setState(() {
        _error = 'siteId, dong, ho를 모두 입력해주세요.';
        _isSubmitting = false;
      });
      return;
    }
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'DJ OAuth 토큰이 없습니다. 먼저 로그인해주세요.';
        _isSubmitting = false;
      });
      return;
    }

    final nickname = username ?? 'unknown_user';
    final payload = {
      'siteId': siteId,
      'dong': dong,
      'ho': ho,
      'nickname': nickname,
    };

    try {
      final res = await http.post(
        Uri.parse('/api/dj-oauth/household'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) {
        return;
      }
      if (res.statusCode >= 200 && res.statusCode < 300) {
        setState(() {
          _result = res.body.isEmpty ? 'OK' : res.body;
          _isSubmitting = false;
        });
        return;
      }
      setState(() {
        _error = '요청 실패: ${res.statusCode} ${res.body}';
        _isSubmitting = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '요청 에러: $e';
        _isSubmitting = false;
      });
    }
  }

  Future<void> _requestReboot() async {
    setState(() {
      _error = null;
      _result = null;
      _isRebooting = true;
    });

    final rawSiteId = _siteIdController.text.trim();
    final rawDong = _dongController.text.trim();
    final rawHo = _hoController.text.trim();
    final token = SessionService.getAccessToken();

    final siteId = int.tryParse(rawSiteId);
    final dong = int.tryParse(rawDong);
    final ho = int.tryParse(rawHo);

    if (siteId == null || dong == null || ho == null) {
      setState(() {
        _error = 'siteId, dong, ho는 숫자로 입력해주세요.';
        _isRebooting = false;
      });
      await _showStatusDialog(
        title: '리부팅 요청 실패',
        message: 'siteId, dong, ho는 숫자로 입력해주세요.',
        isError: true,
      );
      return;
    }
    if (token == null || token.isEmpty) {
      setState(() {
        _error = 'HT OAuth 토큰이 없습니다. 먼저 로그인해주세요.';
        _isRebooting = false;
      });
      await _showStatusDialog(
        title: '리부팅 요청 실패',
        message: 'HT OAuth 토큰이 없습니다. 먼저 로그인해주세요.',
        isError: true,
      );
      return;
    }

    final payload = {
      'site_id': siteId,
      'dong': dong,
      'ho': ho,
    };

    try {
      final res = await http.post(
        Uri.parse('/api/ht-oauth/reboot'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );
      if (!mounted) {
        return;
      }

      final parsed = _parseJsonMap(res.body);
      final ok = parsed?['ok'] == true;
      final errorType = parsed?['error_type']?.toString();
      final detail = parsed?['detail']?.toString();

      if (res.statusCode >= 200 && res.statusCode < 300 && ok) {
        final message = detail == null || detail.isEmpty
            ? '리부팅 요청을 전송했습니다.'
            : detail;
        setState(() {
          _result = message;
          _isRebooting = false;
        });
        await _showStatusDialog(
          title: '리부팅 요청 완료',
          message: message,
          isError: false,
        );
        return;
      }

      final explain = _explainRebootFailure(
        statusCode: res.statusCode,
        errorType: errorType,
        detail: detail,
        rawBody: res.body,
      );
      setState(() {
        _error = explain;
        _isRebooting = false;
      });
      await _showStatusDialog(
        title: '리부팅 요청 실패',
        message: explain,
        isError: true,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _error = '리부팅 요청 전송 중 오류가 발생했습니다: $e';
        _isRebooting = false;
      });
      await _showStatusDialog(
        title: '리부팅 요청 실패',
        message: '리부팅 요청 전송 중 오류가 발생했습니다.\n$e',
        isError: true,
      );
    }
  }

  Map<String, dynamic>? _parseJsonMap(String raw) {
    if (raw.isEmpty) {
      return null;
    }
    try {
      final value = jsonDecode(raw);
      if (value is Map<String, dynamic>) {
        return value;
      }
    } catch (_) {
      // Ignore non-JSON body.
    }
    return null;
  }

  String _explainRebootFailure({
    required int statusCode,
    required String? errorType,
    required String? detail,
    required String rawBody,
  }) {
    final base = switch (errorType) {
      'REQUEST_FAILED' =>
        '우리 서버에서 wallpad 서버로 요청을 보내는 단계에서 실패했습니다.',
      'WALLPAD_RESPONSE_ERROR' =>
        'wallpad 서버가 요청은 받았지만 에러 응답을 반환했습니다.',
      'SITE_MAPPING_NOT_FOUND' =>
        'siteId에 매핑된 wallpad IP를 찾지 못했습니다 (info_danji.txt 확인 필요).',
      'TOKEN_MISSING' => 'HT OAuth 토큰이 없어 리부팅 요청을 진행할 수 없습니다.',
      _ => '리부팅 요청 처리 중 오류가 발생했습니다.',
    };
    final detailText = (detail == null || detail.isEmpty) ? '' : '\n상세: $detail';
    final bodyText = rawBody.isEmpty ? '' : '\n응답: $rawBody';
    return '$base\nHTTP: $statusCode$detailText$bodyText';
  }

  Future<void> _showStatusDialog({
    required String title,
    required String message,
    required bool isError,
  }) async {
    if (!mounted) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: Text(message)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(isError ? '확인' : '닫기'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: BsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const PageHelpBox(
                  message: '세대 접근 권한 요청 API를 테스트할 수 있는 페이지입니다.',
                ),
                const SizedBox(height: 16),
                const BsText(
                  '세대 접근',
                  variant: BsTextVariant.title,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                BsTextField(
                  controller: _siteIdController,
                  label: 'siteId',
                ),
                const SizedBox(height: 12),
                BsTextField(
                  controller: _dongController,
                  label: 'dong',
                ),
                const SizedBox(height: 12),
                BsTextField(
                  controller: _hoController,
                  label: 'ho',
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    BsButton(
                      onPressed: (_isSubmitting || _isRebooting)
                          ? null
                          : _requestHouseholdAccess,
                      label: _isSubmitting ? '요청 중..' : '접근요청',
                    ),
                    const SizedBox(width: 10),
                    BsButton(
                      onPressed: (_isSubmitting || _isRebooting)
                          ? null
                          : _requestReboot,
                      label: _isRebooting ? '리부팅 중..' : '리부팅',
                      outline: true,
                    ),
                  ],
                ),
                if (_result != null) ...[
                  const SizedBox(height: 12),
                  BsAlert(
                    message: _result!,
                    variant: BsVariant.success,
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  BsAlert(
                    message: _error!,
                    variant: BsVariant.danger,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
