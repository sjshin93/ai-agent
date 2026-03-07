import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/auth_service.dart';
import '../../services/browser_redirect.dart';
import '../../services/session_service.dart';
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
  String? _errorMessage;
  static const _googleRed = Color(0xFFDB4437);
  static const _googleRedBorder = Color(0xFFF2C9C5);

  @override
  void initState() {
    super.initState();
    final googleStatus = Uri.base.queryParameters['google'];
    final kakaoStatus = Uri.base.queryParameters['kakao'];
    if (googleStatus == 'error') {
      _errorMessage = 'Google login failed. Please verify OAuth settings.';
    } else if (kakaoStatus == 'error') {
      _errorMessage = 'Kakao login failed. Please verify OAuth settings.';
    }
    _restoreSessionIfExists();
  }

  Future<void> _restoreSessionIfExists() async {
    try {
      final me = await _auth.me();
      if (!mounted || !me.authenticated) {
        return;
      }
      SessionService.setUsername(me.userId ?? 'unknown-user');
      SessionService.setAccessToken(null);
      Navigator.of(context).pushReplacementNamed(AppRoutes.main);
    } catch (_) {
      // Ignore. User can still login manually.
    }
  }

  void _continueWithGoogleLogin() {
    redirectTo('/api/auth/google/login');
  }

  void _continueWithKakaoLogin() {
    redirectTo('/api/auth/kakao/login');
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
