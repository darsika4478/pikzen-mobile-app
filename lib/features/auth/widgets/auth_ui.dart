import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';

const authBackground = Color(0xFFF8F9FF);

class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: authBackground,
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: child,
          ),
        ),
      ),
    ),
  );
}

class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.size = 60});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    padding: const EdgeInsets.all(8),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .1),
          blurRadius: 14,
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.asset(AppAssets.logo, fit: BoxFit.cover),
    ),
  );
}

class AuthBadge extends StatelessWidget {
  const AuthBadge(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class AuthInput extends StatefulWidget {
  const AuthInput({
    super.key,
    required this.label,
    required this.controller,
    required this.validator,
    this.secret = false,
    this.icon = Icons.mail_outline,
    this.keyboardType = TextInputType.text,
    this.prefix,
    this.onSubmitted,
  });
  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String> validator;
  final bool secret;
  final IconData icon;
  final TextInputType keyboardType;
  final Widget? prefix;
  final VoidCallback? onSubmitted;
  @override
  State<AuthInput> createState() => _AuthInputState();
}

class _AuthInputState extends State<AuthInput> {
  bool hidden = true;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: CustomTextField(
      label: widget.label,
      controller: widget.controller,
      validator: widget.validator,
      obscureText: widget.secret && hidden,
      keyboardType: widget.keyboardType,
      textInputAction: widget.onSubmitted == null
          ? TextInputAction.next
          : TextInputAction.done,
      onFieldSubmitted: widget.onSubmitted == null
          ? null
          : (_) => widget.onSubmitted!(),
      prefixIcon: widget.prefix ?? Icon(widget.icon, size: 20),
      suffixIcon: widget.secret
          ? IconButton(
              tooltip: hidden
                  ? 'Show ${widget.label.toLowerCase()}'
                  : 'Hide ${widget.label.toLowerCase()}',
              onPressed: () => setState(() => hidden = !hidden),
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                size: 20,
              ),
            )
          : null,
    ),
  );
}

class AuthAction extends StatelessWidget {
  const AuthAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });
  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: busy ? null : onPressed,
      child: busy
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Flexible(child: Text(label)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 18),
              ],
            ),
    ),
  );
}

class AuthError extends StatelessWidget {
  const AuthError(this.message, {super.key});
  final String? message;
  @override
  Widget build(BuildContext context) => message == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Semantics(
            liveRegion: true,
            child: Text(
              message!,
              style: const TextStyle(color: AppColors.error),
              textAlign: TextAlign.center,
            ),
          ),
        );
}
