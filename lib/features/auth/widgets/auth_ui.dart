import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/constants/app_colors.dart';
import '../../../shared/widgets/custom_text_field.dart';

const authBackground = Color(0xFFF8F9FF);

/// Auth screens start at the top with even margins. Screens without a back
/// button can set [centered] so a short form sits in the middle of a tall
/// phone instead of leaving its lower half empty.
class AuthPage extends StatelessWidget {
  const AuthPage({super.key, required this.child, this.centered = false});
  final Widget child;
  final bool centered;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: authBackground,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          // Fills phones edge to edge (also zoomed-out ones); caps tablets.
          constraints: const BoxConstraints(maxWidth: 560),
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
              child: centered
                  ? ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: (constraints.maxHeight - 40).clamp(
                          0,
                          double.infinity,
                        ),
                      ),
                      child: Center(child: child),
                    )
                  : child,
            ),
          ),
        ),
      ),
    ),
  );
}

/// The square PikZen app icon, matching the launcher icon.
class AuthLogo extends StatelessWidget {
  const AuthLogo({super.key, this.size = 76});
  final double size;
  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(size * .28),
      boxShadow: [
        BoxShadow(
          color: AppColors.primary.withValues(alpha: .14),
          blurRadius: 22,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(size * .28),
      child: Image.asset(AppAssets.appIcon, fit: BoxFit.cover),
    ),
  );
}

class AuthBadge extends StatelessWidget {
  const AuthBadge(this.text, {super.key, this.icon});
  final String text;
  final IconData? icon;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.softGreen,
      borderRadius: BorderRadius.circular(30),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
        ],
        // Stays on one line normally; wraps instead of overflowing when the
        // text is enlarged on a narrow screen.
        Flexible(
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
              letterSpacing: .4,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Neutral round back button used across the auth screens.
class AuthBackButton extends StatelessWidget {
  const AuthBackButton({
    super.key,
    required this.onPressed,
    this.tooltip = 'Back',
  });
  final VoidCallback? onPressed;
  final String tooltip;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    style: IconButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: AppColors.primaryText,
      side: const BorderSide(color: AppColors.border),
      fixedSize: const Size(44, 44),
    ),
    icon: const Icon(Icons.arrow_back, size: 20),
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

/// White rounded surface that groups form fields.
class AuthCard extends StatelessWidget {
  const AuthCard({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
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
    child: child,
  );
}
