import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../services/browser_redirect.dart';
import '../../services/session_service.dart';
import '../../services/turnstile_service.dart';
import '../main/services/config_service.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _auth = AuthService();
  final _config = ConfigService();
  final _turnstile = TurnstileService();
  String? _errorMessage;
  bool _turnstileEnabled = false;
  static const _googleRed = Color(0xFFDB4437);
  static const _googleRedBorder = Color(0xFFF2C9C5);

  @override
  void initState() {
    super.initState();
    final googleStatus = Uri.base.queryParameters['google'];
    final kakaoStatus = Uri.base.queryParameters['kakao'];
    if (googleStatus == 'error') {
      _errorMessage = 'Google login failed. Please verify OAuth and Turnstile settings.';
    } else if (kakaoStatus == 'error') {
      _errorMessage = 'Kakao login failed. Please verify OAuth and Turnstile settings.';
    }
    _loadTurnstileConfig();
    _restoreSessionIfExists();
  }

  Future<void> _loadTurnstileConfig() async {
    final cfg = await _config.getTurnstileConfig();
    final siteKey = cfg.siteKey?.trim() ?? '';
    if (!cfg.enabled || siteKey.isEmpty) {
      if (!mounted) {
        return;
      }
      setState(() {
        _turnstileEnabled = false;
      });
      return;
    }
    await _turnstile.configure(siteKey);
    if (!mounted) {
      return;
    }
    setState(() {
      _turnstileEnabled = true;
    });
  }

  Future<void> _restoreSessionIfExists() async {
    try {
      final me = await _auth.me();
      if (!me.authenticated) {
        SessionService.setUsername(null);
        SessionService.setAccessToken(null);
        SessionService.setUserRole(null);
      }
      if (!mounted || !me.authenticated) {
        return;
      }
      SessionService.setUsername(me.userId ?? 'unknown-user');
      SessionService.setAccessToken(null);
      SessionService.setUserRole((me.role ?? 'user').toLowerCase());
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } catch (_) {
      // Ignore. User can still login manually.
    }
  }

  Future<String?> _buildLoginUrl(String baseUrl) async {
    if (!_turnstileEnabled) {
      return baseUrl;
    }
    final existingToken = _turnstile.getToken();
    debugPrint('Turnstile existingToken: $existingToken');
    if (existingToken != null && existingToken.isNotEmpty) {
      return '$baseUrl?turnstile_token=${Uri.encodeQueryComponent(existingToken)}';
    }
    if (mounted) {
      setState(() {
        _errorMessage = _turnstile.isManualMode()
            ? 'Please complete the security check first.'
            : 'Security token is missing or expired. Please refresh and try again.';
      });
    }
    return null;
  }

  Future<void> _continueWithGoogleLogin() async {
    final url = await _buildLoginUrl('/api/auth/google/login');
    if (url == null) {
      return;
    }
    redirectTo(url);
  }

  Future<void> _continueWithKakaoLogin() async {
    final url = await _buildLoginUrl('/api/auth/kakao/login');
    if (url == null) {
      return;
    }
    redirectTo(url);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: BsCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const BsText(
                    'Enter',
                    variant: BsTextVariant.title,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const BsText(
                    'Sign in with Google or Kakao.',
                    variant: BsTextVariant.muted,
                    textAlign: TextAlign.center,
                  ),
                  if (_turnstileEnabled) ...[
                    const SizedBox(height: 8),
                    const BsText(
                      'Cloudflare Turnstile is enabled.',
                      variant: BsTextVariant.muted,
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _continueWithGoogleLogin,
                      icon: const Text(
                        'G',
                        style: TextStyle(
                          color: _googleRed,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      label: const Text(
                        'Continue with Google',
                        style: TextStyle(
                          color: _googleRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _googleRed,
                        side: const BorderSide(color: _googleRedBorder),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  BsButton(
                    onPressed: _continueWithKakaoLogin,
                    label: 'Continue with Kakao',
                    fullWidth: true,
                  ),
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    BsText(
                      _errorMessage!,
                      variant: BsTextVariant.muted,
                      textAlign: TextAlign.center,
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
