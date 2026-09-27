class Validators {
  Validators._();
  static String? email(String? value) {
    final email = (value ?? '').trim();
    if (email.length > 254 ||
        !RegExp(
          r'^[A-Za-z0-9.!#$%&*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)+$',
        ).hasMatch(email) ||
        email.startsWith('.') ||
        email.contains('..') ||
        email.contains('.@')) {
      return 'Enter a valid email address';
    }
    return null;
  }

  static String? password(String? value) => (value ?? '').length < 8
      ? 'Password must contain at least 8 characters'
      : null;
  static String? name(String? value) =>
      (value ?? '').trim().length < 2 ? 'Enter your full name' : null;
  static String normalizePhone(String value) {
    var digits = value.replaceAll(RegExp(r'[\s()-]'), '');
    if (digits.startsWith('+94')) return digits;
    if (digits.startsWith('94') && digits.length == 11) return '+$digits';
    if (digits.startsWith('0')) digits = digits.substring(1);
    return '+94$digits';
  }

  static String? phone(String? value) =>
      RegExp(r'^\+947\d{8}$').hasMatch(normalizePhone(value ?? ''))
      ? null
      : 'Enter a valid Sri Lankan mobile number';
  static bool isPhoneInput(String value) =>
      value.trim().isNotEmpty &&
      RegExp(r'^\+?[\d\s()-]+$').hasMatch(value.trim());
}
