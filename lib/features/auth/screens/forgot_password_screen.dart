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
  bool get _mobile => Validators.isPhoneInput(_input.text);
  @override
  void initState() {
    super.initState();
    _input.addListener(_changed);
  }

  void _changed() => setState(() => _success = null);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _reset() async {
    if (_mobile || !(_form.currentState?.validate() ?? false)) return;
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
          Row(
            children: [
              IconButton.filledTonal(
                tooltip: 'Back to Login',
                onPressed: () => context.goNamed('login'),
                icon: const Icon(Icons.arrow_back),
              ),
              const Spacer(),
              const Flexible(child: AuthBadge('ACCOUNT RECOVERY')),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 24),
          Image.asset(
            'assets/images/forgot pw.png',
            width: 120,
            height: 110,
            fit: BoxFit.contain,
            excludeFromSemantics: true,
          ),
          const SizedBox(height: 18),
          Text(
            'Forgot Password?',
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          const Text(
            'Enter your registered email address to receive a secure password reset link.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.secondaryText),
          ),
          const SizedBox(height: 26),
          Form(
            key: _form,
            autovalidateMode: AutovalidateMode.onUserInteraction,
            child: TextFormField(
              controller: _input,
              keyboardType: _mobile
                  ? TextInputType.phone
                  : TextInputType.emailAddress,
              validator: _mobile ? Validators.phone : Validators.email,
              decoration: InputDecoration(
                labelText: 'Registered Email or Mobile',
                prefixIcon: Icon(
                  _mobile ? Icons.phone_outlined : Icons.mail_outline,
                ),
                suffixIcon: IconButton(
                  tooltip: 'Clear',
                  onPressed: _input.clear,
                  icon: const Icon(Icons.cancel_outlined, size: 18),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _RecoveryChoice(
                  label: 'Send to Email',
                  icon: Icons.alternate_email,
                  selected: !_mobile,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RecoveryChoice(
                  label: 'SMS Passcode',
                  icon: Icons.sms_outlined,
                  selected: _mobile,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_mobile)
            const Padding(
              padding: EdgeInsets.only(bottom: 16),
              child: Text(
                'Phone recovery is not configured for this app. A registration phone number does not enable SMS password reset. Please enter your account email to reset your password.',
                style: TextStyle(color: AppColors.secondaryText),
                textAlign: TextAlign.center,
              ),
            ),
          AuthError(auth.error),
          if (_success != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _success!,
                  style: const TextStyle(color: AppColors.primary),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          AuthAction(
            label: _mobile ? 'SMS unavailable' : 'Send Reset Link',
            busy: auth.busy,
            onPressed: !_mobile && Validators.email(_input.text) == null
                ? _reset
                : null,
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
                    Image.asset(
                      'assets/images/Hotline.png',
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
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

class _RecoveryChoice extends StatelessWidget {
  const _RecoveryChoice({
    required this.label,
    required this.icon,
    required this.selected,
  });
  final String label;
  final IconData icon;
  final bool selected;
  @override
  Widget build(BuildContext context) => Semantics(
    selected: selected,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? Colors.white : const Color(0xFFF0F5FC),
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: AppColors.softGreen) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 16,
            color: selected ? AppColors.primary : AppColors.secondaryText,
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                color: selected ? AppColors.primary : AppColors.secondaryText,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
