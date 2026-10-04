import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/profile/screens/edit_profile_screen.dart';
import 'package:pikzen/features/profile/widgets/merchant_profile_view.dart';
import 'package:pikzen/features/shop_management/widgets/dashboard_bottom_nav.dart';

const initialValues = [
  'GreenMart',
  '012-345 6789',
  'contact@greenmart.my',
  'No. 12, Main Street, Central Plaza',
];

void main() {
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Merchant editor fits $width px and scrolls above keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EditProfileScreen.shopPartner(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(TextFormField), findsNWidgets(4));
      expect(find.byType(DashboardBottomNav), findsNothing);
      final scaffold = tester.widget<Scaffold>(find.byType(Scaffold));
      expect(scaffold.bottomNavigationBar, isNull);
      expect(scaffold.resizeToAvoidBottomInset, isTrue);
      for (var i = 0; i < 4; i++) {
        expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).at(i))
              .controller!
              .text,
          initialValues[i],
        );
      }
      expect(
        tester.widget<Text>(find.text('Edit Profile')).textAlign ??
            TextAlign.start,
        TextAlign.start,
      );
      final fields = find.byType(TextFormField);
      final phone = tester.widget<TextField>(
        find.descendant(of: fields.at(1), matching: find.byType(TextField)),
      );
      final email = tester.widget<TextField>(
        find.descendant(of: fields.at(2), matching: find.byType(TextField)),
      );
      expect(phone.keyboardType, TextInputType.phone);
      expect(email.keyboardType, TextInputType.emailAddress);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: fields.last,
                matching: find.byType(TextField),
              ),
            )
            .maxLines,
        3,
      );
      final save = tester.getRect(find.text('Save Changes'));
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -140),
      );
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Save Changes')), save);
      tester.view.viewInsets = const FakeViewPadding(bottom: 280);
      await tester.pumpAndSettle();
      await tester.ensureVisible(fields.last);
      await tester.enterText(
        fields.last,
        'Updated street\nSecond address line',
      );
      await tester.pumpAndSettle();
      final addressRect = tester.getRect(fields.last);
      expect(
        addressRect.bottom,
        lessThanOrEqualTo(tester.getRect(find.text('Save Changes')).top),
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'Photo controls, required fields, email validation and local save',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const EditProfileScreen.shopPartner(),
        ),
      );
      await tester.pumpAndSettle();
      for (final photoAction in [
        find.byTooltip('Change store photo'),
        find.text('Change Store Photo'),
      ]) {
        await tester.tap(photoAction);
        await tester.pumpAndSettle();
        expect(find.text('Change store photo'), findsOneWidget);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      }
      final fields = find.byType(TextFormField);
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(fields.at(i));
        await tester.enterText(fields.at(i), '');
      }
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      for (final message in [
        'Shop name is required',
        'Phone number is required',
        'Email address is required',
        'Store address is required',
      ]) {
        expect(find.text(message), findsOneWidget);
      }
      final updated = [
        'Local Shop',
        '098-765 4321',
        'invalid-email',
        'New address\nSuite 2',
      ];
      for (var i = 0; i < 4; i++) {
        await tester.ensureVisible(fields.at(i));
        await tester.enterText(fields.at(i), updated[i]);
      }
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address'), findsOneWidget);
      expect(find.text('Profile changes saved'), findsNothing);
      await tester.ensureVisible(fields.at(2));
      await tester.enterText(fields.at(2), 'local@example.com');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Profile changes saved'), findsOneWidget);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'Local Shop',
      );
      expect(
        tester.widget<TextFormField>(fields.last).controller!.text,
        'New address\nSuite 2',
      );
      expect(find.byType(EditProfileScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Avatar edit opens merchant form, Back restores Profile, reopening resets mocks',
    (tester) async {
      await tester.pumpWidget(const PikZenApp());
      appRouter.goNamed('shop-profile');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Edit merchant profile'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<EditProfileScreen>(find.byType(EditProfileScreen))
            .isShopPartner,
        isTrue,
      );
      expect(find.byType(DashboardBottomNav), findsNothing);
      await tester.enterText(find.byType(TextFormField).first, 'Preview shop');
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(find.text('Profile changes saved'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.byType(MerchantProfileView), findsOneWidget);
      expect(find.text('GreenMart'), findsOneWidget);
      expect(
        tester
            .widget<DashboardBottomNav>(find.byType(DashboardBottomNav))
            .selectedIndex,
        3,
      );
      await tester.tap(find.byTooltip('Edit merchant profile'));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextFormField>(find.byType(TextFormField).first)
            .controller!
            .text,
        'GreenMart',
      );
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      appRouter.goNamed('shop-dashboard');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
