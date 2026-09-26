import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/core/utils/validators.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/auth/screens/login_screen.dart';
import 'package:pikzen/features/auth/screens/signup_screen.dart';
import 'package:pikzen/features/auth/screens/forgot_password_screen.dart';
import 'package:pikzen/features/auth/widgets/auth_ui.dart';

import 'auth_test_support.dart';

void main() {
  test(
    'Validation rejects malformed email, short passwords, and invalid phones',
    () {
      for (final value in [
        '',
        'name',
        'a@',
        'a@b',
        'a..b@example.com',
        'a@-bad.com',
        'a b@example.com',
      ]) {
        expect(Validators.email(value), isNotNull);
      }
      expect(Validators.email('alex.perera@example.com'), isNull);
      expect(Validators.password('1234567'), isNotNull);
      expect(Validators.password('12345678'), isNull);
      expect(Validators.normalizePhone('077 123 4567'), '+94771234567');
      expect(Validators.phone('+94771234567'), isNull);
      expect(Validators.phone('123'), isNotNull);
      expect(Validators.isPhoneInput(''), isFalse);
    },
  );
  test('Role routing and Google share the common provider', () async {
    for (final role in ['customer', 'shop', 'admin']) {
      final service = FakeAuthService(
        role: role,
        approvalStatus: role == 'shop' ? 'approved' : null,
      );
      final auth = AuthProvider(service: service, restore: false);
      auth.setRemember(true);
      final ok = await auth.signIn('alex@example.com', 'password123');
      expect(ok, role != 'admin');
      expect(service.rememberedValue, isTrue);
      expect(
        auth.destination,
        role == 'customer'
            ? 'customer-home'
            : role == 'shop'
            ? 'shop-dashboard'
            : null,
      );
      if (role != 'admin') {
        expect(await auth.google(), isTrue);
        expect(service.googleCalls, 1);
      }
      auth.dispose();
    }
  });
  Future<AuthProvider> mount(WidgetTester tester, Widget screen) async {
    final auth = AuthProvider(service: FakeAuthService(), restore: false);
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: MaterialApp(theme: AppTheme.lightTheme, home: screen),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  testWidgets('Login validates and password visibility and Remember Me work', (
    tester,
  ) async {
    final auth = await mount(tester, const LoginScreen());
    expect(find.text('Admin Demo'), findsNothing);
    expect(find.text('Customer / Shop Login'), findsNothing);
    expect(
      tester.widget<AuthAction>(find.byType(AuthAction)).onPressed,
      isNull,
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'alex@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'Password123');
    await tester.pump();
    expect(
      tester.widget<AuthAction>(find.byType(AuthAction)).onPressed,
      isNotNull,
    );
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isTrue,
    );
    await tester.ensureVisible(find.byTooltip('Show password'));
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(
      tester.widget<TextField>(find.byType(TextField).at(1)).obscureText,
      isFalse,
    );
    await tester.ensureVisible(find.byType(Checkbox));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(auth.rememberMe, isTrue);
  });
  testWidgets(
    'Registration button stays present and requires valid data plus terms',
    (tester) async {
      await mount(tester, const SignUpScreen());
      final fields = find.byType(TextFormField);
      for (final entry in {
        0: 'Alex Perera',
        1: 'alex@example.com',
        2: '771234567',
        3: 'Password123',
        4: 'Password123',
      }.entries) {
        await tester.enterText(fields.at(entry.key), entry.value);
      }
      await tester.pump();
      expect(
        tester.widget<AuthAction>(find.byType(AuthAction)).onPressed,
        isNull,
      );
      await tester.ensureVisible(find.byType(Checkbox));
      await tester.tap(find.byType(Checkbox));
      await tester.pump();
      expect(
        tester.widget<AuthAction>(find.byType(AuthAction)).onPressed,
        isNotNull,
      );
      await tester.ensureVisible(find.byTooltip('Show password'));
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(3)).obscureText,
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).at(4)).obscureText,
        isTrue,
      );
      await tester.ensureVisible(find.byTooltip('Show confirm password'));
      await tester.tap(find.byTooltip('Show confirm password'));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField).at(4)).obscureText,
        isFalse,
      );
      await tester.enterText(fields.at(4), 'different');
      await tester.pump();
      expect(
        tester.widget<AuthAction>(find.byType(AuthAction)).onPressed,
        isNull,
      );
    },
  );
  testWidgets('Recovery detects email/mobile without faking SMS success', (
    tester,
  ) async {
    await mount(tester, const ForgotPasswordScreen());
    await tester.enterText(find.byType(TextFormField), '+94771234567');
    await tester.pump();
    expect(find.byIcon(Icons.phone_outlined), findsOneWidget);
    expect(
      tester.widget<AuthAction>(find.byType(AuthAction)).onPressed,
      isNull,
    );
    await tester.enterText(find.byType(TextFormField), 'alex@example.com');
    await tester.pump();
    expect(find.byIcon(Icons.mail_outline), findsOneWidget);
    await tester.ensureVisible(find.text('Send Reset Link'));
    await tester.tap(find.text('Send Reset Link'));
    await tester.pumpAndSettle();
    expect(
      find.text('Password reset link sent. Please check your email.'),
      findsOneWidget,
    );
  });
}
