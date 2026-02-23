import 'package:flutter/material.dart';

import '../../routes.dart';
import '../../services/session_service.dart';
import '../../widgets/bs/bs_button.dart';
import '../../widgets/bs/bs_card.dart';
import '../../widgets/bs/bs_text.dart';
import '../../widgets/bs/bs_text_field.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _userController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _userController.text = SessionService.getUsername() ?? '';
  }

  @override
  void dispose() {
    _userController.dispose();
    super.dispose();
  }

  void _continueWithoutCompanyLogin() {
    final username = _userController.text.trim();
    SessionService.setUsername(username.isEmpty ? 'local-user' : username);
    SessionService.setAccessToken(null);
    SessionService.setDjAccessToken(null);
    Navigator.of(context).pushReplacementNamed(AppRoutes.main);
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
                    'Company auth login (HT/DanJi) has been removed.',
                    variant: BsTextVariant.muted,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  BsTextField(
                    controller: _userController,
                    label: 'Username (optional)',
                  ),
                  const SizedBox(height: 12),
                  BsButton(
                    onPressed: _continueWithoutCompanyLogin,
                    label: 'Continue',
                    fullWidth: true,
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
