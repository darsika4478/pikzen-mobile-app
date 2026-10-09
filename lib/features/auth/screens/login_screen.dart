import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_ui.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool get _valid =>
      Validators.email(_email.text) == null &&
      Validators.password(_password.text) == null;
  @override
  void initState() {
    super.initState();
    _email.addListener(_changed);
    _password.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit({bool google = false}) async {
    final auth = context.read<AuthProvider>();
    if (!google && !(_form.currentState?.validate() ?? false)) return;
    final success = google
        ? await auth.google()
        : await auth.signIn(_email.text, _password.text);
    if (!mounted) return;
    if (success) context.goNamed(auth.destination!);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AuthPage(
      centered: true,
      child: Column(
        children: [
          const SizedBox(height: 8),
          const AuthLogo(),
          const SizedBox(height: 18),
          const AuthBadge('Fresh \u2022 Fast \u2022 Pick Up Ready'),
          const SizedBox(height: 12),
          Text(
            'Welcome Back!',
            style: Theme.of(context).textTheme.headlineMedium
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Sign in to access your pre-orders and freshly curated groceries.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 28),
          Container(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .06),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Form(
              key: _form,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                children: [
                  AuthInput(
                    label: 'Email Address',
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AuthInput(
                    label: 'Password',
                    controller: _password,
                    validator: Validators.password,
                    icon: Icons.lock_outline,
                    secret: true,
                    onSubmitted: _valid && !auth.busy ? _submit : null,
                  ),
                  // One line normally; wraps onto two with very large text.
                  SizedBox(
                    width: double.infinity,
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        InkWell(
                          borderRadius: BorderRadius.circular(8),
                          onTap: auth.busy
                              ? null
                              : () => auth.setRemember(!auth.rememberMe),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 32,
                                height: 32,
                                child: Checkbox(
                                  value: auth.rememberMe,
                                  onChanged: auth.busy
                                      ? null
                                      : (value) =>
                                            auth.setRemember(value ?? false),
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Flexible(
                                child: Text(
                                  'Remember me',
                                  style: TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 4),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: auth.busy
                              ? null
                              : () => context.pushNamed('forgot-password'),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                          ),
                          child: const Text(
                            'Forgot Password?',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  AuthError(auth.error),
                  AuthAction(
                    label: 'Sign In',
                    busy: auth.busy,
                    onPressed: _valid ? _submit : null,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              const Expanded(child: Divider()),
              // Not flexible, so both lines get equal space and the label is
              // centred; the width cap makes it wrap at very large text sizes.
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 200),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'OR CONTINUE WITH',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: .6,
                      color: AppColors.secondaryText,
                    ),
                  ),
                ),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: auth.busy ? null : () => _submit(google: true),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                backgroundColor: Colors.white,
                foregroundColor: AppColors.primaryText,
                side: const BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/icons/Google icon.png',
                    width: 22,
                    height: 22,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 12),
                  const Flexible(child: Text('Continue with Google')),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Don't have an account?"),
              TextButton(
                onPressed: auth.busy ? null : () => context.pushNamed('signup'),
                child: const Text('Sign Up'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
