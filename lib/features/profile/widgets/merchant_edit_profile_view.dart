import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../shop_management/widgets/product_form_controls.dart';

/// Local form state, discarded when the merchant editor is closed.
class MerchantEditProfileView extends StatefulWidget {
  const MerchantEditProfileView({super.key});
  @override
  State<MerchantEditProfileView> createState() =>
      _MerchantEditProfileViewState();
}

class _MerchantEditProfileViewState extends State<MerchantEditProfileView> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController(text: 'GreenMart');
  final _phone = TextEditingController(text: '012-345 6789');
  final _email = TextEditingController(text: 'contact@greenmart.my');
  final _address = TextEditingController(
    text: 'No. 12, Main Street, Central Plaza',
  );

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void _back() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('shop-profile');
    }
  }

  void _save() {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      _message('Profile changes saved');
    }
  }

  Widget _field(
    String label,
    TextEditingController controller,
    String requiredMessage, {
    TextInputType? keyboard,
    int lines = 1,
    bool email = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          maxLines: lines,
          textInputAction: lines > 1
              ? TextInputAction.newline
              : TextInputAction.next,
          style: const TextStyle(fontSize: 12, color: AppColors.primaryText),
          textAlignVertical: TextAlignVertical.top,
          decoration: productFieldDecoration('').copyWith(
            filled: true,
            fillColor: AppColors.surface,
            errorStyle: const TextStyle(fontSize: 10),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.rejectRed),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: AppColors.rejectRed),
            ),
          ),
          validator: (value) {
            final text = value?.trim() ?? '';
            if (text.isEmpty) {
              return requiredMessage;
            }
            if (email &&
                !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(text)) {
              return 'Enter a valid email address';
            }
            return null;
          },
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) => Scaffold(
    resizeToAvoidBottomInset: true,
    backgroundColor: AppColors.background,
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 10, 16, 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _back,
                      tooltip: 'Back',
                      icon: const Icon(
                        Icons.chevron_left_rounded,
                        size: 24,
                        color: AppColors.primaryText,
                      ),
                    ),
                    const SizedBox(width: 2),
                    const Expanded(
                      child: Text(
                        'Edit Profile',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        StorePhotoEditor(
                          onChange: () => _message('Change store photo'),
                        ),
                        const SizedBox(height: 20),
                        _field('SHOP NAME', _name, 'Shop name is required'),
                        _field(
                          'PHONE NUMBER',
                          _phone,
                          'Phone number is required',
                          keyboard: TextInputType.phone,
                        ),
                        _field(
                          'EMAIL ADDRESS',
                          _email,
                          'Email address is required',
                          keyboard: TextInputType.emailAddress,
                          email: true,
                        ),
                        _field(
                          'STORE ADDRESS',
                          _address,
                          'Store address is required',
                          keyboard: TextInputType.multiline,
                          lines: 3,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(9),
                      ),
                    ),
                    child: const Text(
                      'Save Changes',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class StorePhotoEditor extends StatelessWidget {
  const StorePhotoEditor({super.key, required this.onChange});
  final VoidCallback onChange;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      SizedBox(
        width: 88,
        height: 88,
        child: Stack(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.softGreen,
                border: Border.all(
                  color: AppColors.primaryLight.withValues(alpha: 0.35),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    color: AppColors.primary,
                    size: 33,
                  ),
                  SizedBox(height: 4),
                  Text(
                    'STORE LOGO',
                    style: TextStyle(
                      fontSize: 8,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.surface, width: 2),
                ),
                child: IconButton(
                  onPressed: onChange,
                  tooltip: 'Change store photo',
                  padding: EdgeInsets.zero,
                  style: IconButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  icon: const Icon(
                    Icons.camera_alt_outlined,
                    size: 14,
                    color: AppColors.surface,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      TextButton(
        onPressed: onChange,
        style: TextButton.styleFrom(
          minimumSize: const Size(0, 28),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const Text(
          'Change Store Photo',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ),
    ],
  );
}
