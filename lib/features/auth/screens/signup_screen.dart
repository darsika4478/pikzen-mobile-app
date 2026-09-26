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
  bool _submitted = false;
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
    if (auth.user?.role == 'shop') {
      setState(() => _submitted = true);
    } else {
      context.goNamed(auth.destination!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (_submitted) {
      return AuthPage(
        child: Column(
          children: [
            const AuthLogo(),
            const SizedBox(height: 24),
            Text(
              'Registration Submitted',
              style: Theme.of(context).textTheme.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Text(
              'Your shop account is awaiting admin approval.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AuthAction(
              label: 'Back to Login',
              onPressed: () => context.goNamed('login'),
            ),
          ],
        ),
      );
    }
    final matching =
        _confirm.text.isNotEmpty && _confirm.text == _password.text;
    return AuthPage(
      child: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton.filledTonal(
                  tooltip: 'Back to Login',
                  onPressed: auth.busy ? null : () => context.goNamed('login'),
                  icon: const Icon(Icons.arrow_back),
                ),
                const AuthLogo(size: 40),
              ],
            ),
            const SizedBox(height: 20),
            const AuthBadge('Fresh Pickup Network'),
            const SizedBox(height: 10),
            Text(
              'Create Account',
              style: Theme.of(context).textTheme.headlineMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Text(
              'Join PikZen to pre-order fresh groceries locally with exclusive pickup offers.',
              style: TextStyle(color: AppColors.secondaryText),
            ),
            const SizedBox(height: 24),
            Text('Account Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Customer'),
                  selected: _role == 'customer',
                  onSelected: auth.busy
                      ? null
                      : (_) => setState(() => _role = 'customer'),
                ),
                ChoiceChip(
                  label: const Text('Shop Owner'),
                  selected: _role == 'shop',
                  onSelected: auth.busy
                      ? null
                      : (_) => setState(() => _role = 'shop'),
                ),
              ],
            ),
            const SizedBox(height: 20),
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
            if (_password.text.isNotEmpty) ...[
              LinearProgressIndicator(
                value: (_password.text.length / 12).clamp(0.0, 1.0),
                color: _password.text.length >= 8
                    ? AppColors.primary
                    : AppColors.warning,
                backgroundColor: AppColors.border,
              ),
              const SizedBox(height: 16),
            ],
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
                child: Text(
                  'Passwords match',
                  style: TextStyle(color: AppColors.primary, fontSize: 12),
                ),
              ),
            Material(
              color: const Color(0xFFF0F5FC),
              borderRadius: BorderRadius.circular(14),
              child: CheckboxListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                controlAffinity: ListTileControlAffinity.leading,
                value: _terms,
                onChanged: auth.busy
                    ? null
                    : (value) => setState(() => _terms = value ?? false),
                title: const Text(
                  'I agree to the Terms & Conditions and Privacy Policy.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AuthError(auth.error),
            AuthAction(
              label: 'Create Account',
              busy: auth.busy,
              onPressed: _valid ? _submit : null,
            ),
            const SizedBox(height: 16),
            Center(
              child: Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  const Text('Already have an account?'),
                  TextButton(
                    onPressed: auth.busy
                        ? null
                        : () => context.goNamed('login'),
                    child: const Text('Login'),
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
