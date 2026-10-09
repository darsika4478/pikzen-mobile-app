import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/utils/validators.dart';
import '../../auth/widgets/auth_ui.dart';

/// In-app password change for customers, shops and admins. Re-checks the
/// current password first, as Firebase requires for sensitive changes.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({
    super.key,
    this.service,
    this.emailForTesting,
    this.hasPasswordForTesting,
  });
  final AuthService? service;
  final String? emailForTesting;
  final bool? hasPasswordForTesting;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  late final AuthService _service = widget.service ?? AuthService();
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();
  bool _saving = false;
  bool _sendingReset = false;
  String? _error;

  String? get _email =>
      widget.emailForTesting ??
      (Firebase.apps.isEmpty ? null : FirebaseAuth.instance.currentUser?.email);
  bool get _hasPassword =>
      widget.hasPasswordForTesting ??
      (Firebase.apps.isEmpty ? true : _service.hasPassword);

  @override
  void initState() {
    super.initState();
    for (final controller in [_current, _next, _confirm]) {
      controller.addListener(() => setState(() => _error = null));
    }
  }

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _back() =>
      context.canPop() ? context.pop() : context.goNamed('settings');

  void _snack(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _submit() async {
    if (_saving || !(_form.currentState?.validate() ?? false)) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.changePassword(_current.text, _next.text);
      if (!mounted) return;
      _snack('Password updated.');
      _back();
    } catch (error) {
      if (mounted) setState(() => _error = AuthService.message(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _sendReset() async {
    final email = _email;
    if (email == null || _sendingReset) return;
    setState(() => _sendingReset = true);
    try {
      await _service.resetPassword(email);
      if (mounted) _snack('Reset link sent to $email.');
    } catch (error) {
      if (mounted) _snack(AuthService.message(error));
    } finally {
      if (mounted) setState(() => _sendingReset = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: _saving ? null : _back,
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Change Password'),
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: !_hasPassword
                ? const _GoogleAccountNotice()
                : Form(
                    key: _form,
                    autovalidateMode: AutovalidateMode.onUserInteraction,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Enter your current password, then choose a new one with at least 8 characters.',
                          style: TextStyle(color: AppColors.secondaryText),
                        ),
                        const SizedBox(height: 20),
                        AuthCard(
                          child: Column(
                            children: [
                              AuthInput(
                                label: 'Current Password',
                                controller: _current,
                                validator: (value) => (value ?? '').isEmpty
                                    ? 'Enter your current password'
                                    : null,
                                secret: true,
                                icon: Icons.lock_outline,
                              ),
                              AuthInput(
                                label: 'New Password',
                                controller: _next,
                                validator: Validators.password,
                                secret: true,
                                icon: Icons.lock_reset,
                              ),
                              AuthInput(
                                label: 'Confirm New Password',
                                controller: _confirm,
                                validator: (value) => value == _next.text
                                    ? null
                                    : 'Passwords do not match',
                                secret: true,
                                icon: Icons.verified_user_outlined,
                                onSubmitted: _submit,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        AuthError(_error),
                        AuthAction(
                          label: 'Update Password',
                          busy: _saving,
                          onPressed: _submit,
                        ),
                        const SizedBox(height: 8),
                        if (_email != null)
                          TextButton(
                            onPressed: _sendingReset || _saving
                                ? null
                                : _sendReset,
                            child: Text(
                              _sendingReset ? 'Sending reset link…' : 'Forgot your current password? Email me a reset link',
                              textAlign: TextAlign.center,
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ),
      ),
    ),
  );
}

class _GoogleAccountNotice extends StatelessWidget {
  const _GoogleAccountNotice();
  @override
  Widget build(BuildContext context) => const AuthCard(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, color: AppColors.primary),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            'You sign in with Google, so your password is managed in your Google account settings.',
          ),
        ),
      ],
    ),
  );
}
