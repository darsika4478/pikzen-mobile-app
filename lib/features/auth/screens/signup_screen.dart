import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_ui.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});
  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _terms = false;
  String _role = 'customer';
  List<TextEditingController> get _controllers => [
    _name,
    _email,
    _phone,
    _password,
    _confirm,
  ];
  bool get _valid =>
      _terms &&
      Validators.name(_name.text) == null &&
      Validators.email(_email.text) == null &&
      Validators.phone(_phone.text) == null &&
      Validators.password(_password.text) == null &&
      _confirm.text == _password.text;
  @override
  void initState() {
    super.initState();
    for (final c in _controllers) {
      c.addListener(_changed);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AuthProvider>().clearError();
    });
  }

  void _changed() => setState(() {});
  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_valid || !(_form.currentState?.validate() ?? false)) return;
    final auth = context.read<AuthProvider>();
    final result = await auth.register(
      _name.text,
      _email.text,
      Validators.normalizePhone(_phone.text),
      _password.text,
      role: _role,
    );
    if (!mounted || !result) return;
    context.goNamed(auth.destination!);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final matching =
        _confirm.text.isNotEmpty && _confirm.text == _password.text;
    return AuthPage(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: AuthBackButton(
                tooltip: 'Back to Login',
                onPressed: auth.busy ? null : () => context.goNamed('login'),
              ),
            ),
            const SizedBox(height: 8),
            const Center(
              child: AuthBadge(
                'Fresh Pickup Network',
                icon: Icons.eco_outlined,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create Account',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join PikZen to pre-order fresh groceries from local shops and pick them up on your schedule.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.secondaryText, height: 1.4),
            ),
            const SizedBox(height: 24),
            Text(
              'I am a',
              style: Theme.of(context).textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: SignUpRoleCard(
                    icon: Icons.shopping_basket_outlined,
                    title: 'Customer',
                    subtitle: 'Order & pick up',
                    selected: _role == 'customer',
                    onTap: auth.busy
                        ? null
                        : () => setState(() => _role = 'customer'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SignUpRoleCard(
                    icon: Icons.storefront_outlined,
                    title: 'Shop Owner',
                    subtitle: 'Sell to your area',
                    selected: _role == 'shop',
                    onTap: auth.busy
                        ? null
                        : () => setState(() => _role = 'shop'),
                  ),
                ),
              ],
            ),
            if (_role == 'shop') ...[
              const SizedBox(height: 10),
              const _ShopApprovalNote(),
            ],
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 6),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthInput(
                    label: 'Full Name',
                    controller: _name,
                    validator: Validators.name,
                    icon: Icons.person_outline,
                    keyboardType: TextInputType.name,
                  ),
                  AuthInput(
                    label: 'Email Address',
                    controller: _email,
                    validator: Validators.email,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  AuthInput(
                    label: 'Phone Number',
                    controller: _phone,
                    validator: Validators.phone,
                    keyboardType: TextInputType.phone,
                    prefix: const Padding(
                      padding: EdgeInsets.all(14),
                      child: Text('+94'),
                    ),
                  ),
                  AuthInput(
                    label: 'Password',
                    controller: _password,
                    validator: Validators.password,
                    secret: true,
                    icon: Icons.lock_outline,
                  ),
                  if (_password.text.isNotEmpty)
                    _PasswordStrength(password: _password.text),
                  AuthInput(
                    label: 'Confirm Password',
                    controller: _confirm,
                    validator: (value) =>
                        value == _password.text && (value ?? '').isNotEmpty
                        ? null
                        : 'Passwords do not match',
                    secret: true,
                    icon: Icons.verified_user_outlined,
                  ),
                  if (matching)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 14),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 16,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Passwords match',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Material(
              color: Colors.transparent,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _terms,
                onChanged: auth.busy
                    ? null
                    : (value) => setState(() => _terms = value ?? false),
                title: const Text(
                  'I agree to the Terms & Conditions and Privacy Policy.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 12),
            AuthError(auth.error),
            AuthAction(
              label: 'Create Account',
              busy: auth.busy,
              onPressed: _valid ? _submit : null,
            ),
            const SizedBox(height: 12),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text(
                    'Already have an account?',
                    style: TextStyle(color: AppColors.secondaryText),
                  ),
                  TextButton(
                    onPressed: auth.busy
                        ? null
                        : () => context.goNamed('login'),
                    child: const Text(
                      'Login',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One of the two account-type options, styled as a selectable card.
class SignUpRoleCard extends StatelessWidget {
  const SignUpRoleCard({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    child: Material(
      color: selected ? AppColors.softGreen : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    icon,
                    color: selected
                        ? AppColors.primary
                        : AppColors.secondaryText,
                  ),
                  const Spacer(),
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ShopApprovalNote extends StatelessWidget {
  const _ShopApprovalNote();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.noticeBackground,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.noticeBorder),
    ),
    child: const Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.info_outline, size: 18, color: AppColors.noticeText),
        SizedBox(width: 8),
        Expanded(
          child: Text(
            'Shop accounts are reviewed by an admin before you can start selling.',
            style: TextStyle(fontSize: 12, color: AppColors.noticeText),
          ),
        ),
      ],
    ),
  );
}

/// Bar plus a word (Weak / Fair / Strong) so the meter is not colour-only.
class _PasswordStrength extends StatelessWidget {
  const _PasswordStrength({required this.password});
  final String password;

  @override
  Widget build(BuildContext context) {
    var score = 0;
    if (password.length >= 8) score++;
    if (password.length >= 12) score++;
    if (RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password)) {
      score++;
    }
    if (RegExp(r'\d').hasMatch(password)) score++;
    if (RegExp(r'[^A-Za-z0-9]').hasMatch(password)) score++;
    final (label, color, value) = password.length < 8
        ? ('Too short', AppColors.error, .2)
        : score <= 2
        ? ('Fair', AppColors.warning, .5)
        : score == 3
        ? ('Good', AppColors.primaryLight, .75)
        : ('Strong', AppColors.primary, 1.0);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                color: color,
                backgroundColor: AppColors.border,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
