import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_ui.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _input = TextEditingController();
  final _form = GlobalKey<FormState>();
  String? _success;
  @override
  void initState() {
    super.initState();
    _input.addListener(_changed);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  void _changed() => setState(() => _success = null);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final ok = await context.read<AuthProvider>().reset(_input.text);
    if (mounted && ok) {
      setState(
        () => _success = 'Password reset link sent. Please check your email.',
      );
    }
  }

  Future<void> _call() async {
    try {
      if (await launchUrl(
        Uri.parse('tel:+94112345678'),
        mode: LaunchMode.externalApplication,
      )) {
        return;
      }
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No phone dialer is available on this device. Call +94 11 234 5678.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return AuthPage(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: AuthBackButton(
              tooltip: 'Back to Login',
              onPressed: () => context.goNamed('login'),
            ),
          ),
          const SizedBox(height: 12),
          // The artwork has a white background, so it sits in a white circle.
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: .12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            alignment: Alignment.center,
            // Clipped so the artwork's square white corners stay inside.
            child: ClipOval(
              child: Image.asset(
                'assets/images/forgot pw.png',
                width: 104,
                height: 104,
                fit: BoxFit.contain,
                excludeFromSemantics: true,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Forgot Password?',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            "Enter the email you signed up with and we'll send you a link to reset your password.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 26),
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: AuthInput(
              label: 'Email Address',
              controller: _input,
              validator: Validators.email,
              keyboardType: TextInputType.emailAddress,
              onSubmitted: Validators.email(_input.text) == null && !auth.busy
                  ? _reset
                  : null,
            ),
          ),
          AuthError(auth.error),
          if (_success != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Semantics(
                liveRegion: true,
                child: Row(
                  children: [
                    const Icon(
                      Icons.mark_email_read_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _success!,
                        style: const TextStyle(
                          color: AppColors.darkGreen,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          AuthAction(
            label: 'Send Reset Link',
            busy: auth.busy,
            onPressed: Validators.email(_input.text) == null ? _reset : null,
          ),
          const SizedBox(height: 32),
          Material(
            color: const Color(0xFFF0F5FC),
            borderRadius: BorderRadius.circular(18),
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: _call,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.asset(
                          'assets/images/Hotline.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PICKUP DESK HOTLINE',
                            style: TextStyle(
                              fontSize: 10,
                              color: AppColors.warning,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Need instant help? Contact Colombo Hub Support at',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                          Text(
                            '+94 11 234 5678',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          TextButton.icon(
            onPressed: () => context.goNamed('login'),
            icon: const Icon(Icons.arrow_back, size: 18),
            label: const Text('Back to Login'),
          ),
        ],
      ),
    );
  }
}
