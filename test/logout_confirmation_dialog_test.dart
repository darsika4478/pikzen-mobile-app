import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/profile/widgets/logout_confirmation_dialog.dart';

void main() {
  for (final size in [
    const Size(360, 740),
    const Size(375, 740),
    const Size(390, 740),
    const Size(412, 740),
    const Size(430, 740),
    const Size(740, 360),
    const Size(360, 420),
  ]) {
    testWidgets('Logout dialog fits $size and scrolls with keyboard', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetViewInsets);
      bool? result;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  result = await showDialog<bool>(
                    context: context,
                    barrierColor: Colors.black.withValues(alpha: 0.35),
                    builder: (_) => const LogoutConfirmationDialog(),
                  );
                },
                child: const Text('Open logout'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open logout'));
      await tester.pumpAndSettle();
      expect(find.text('Are you sure you want to logout?'), findsOneWidget);
      expect(find.byType(BackdropFilter), findsOneWidget);
      final rect = tester.getRect(
        find
            .descendant(
              of: find.byType(Dialog),
              matching: find.byType(Material),
            )
            .first,
      );
      expect(rect.center.dx, closeTo(size.width / 2, 1));
      expect(rect.center.dy, closeTo(size.height / 2, 1));
      expect(rect.height, 280);
      expect(rect.width, lessThanOrEqualTo(size.width - 24));
      final logout = tester.getRect(
        find.widgetWithText(ElevatedButton, 'Logout'),
      );
      final cancel = tester.getRect(find.widgetWithText(TextButton, 'Cancel'));
      expect(logout.width, cancel.width);
      expect(logout.height, 36);
      expect(cancel.top - logout.bottom, 8);
      expect(tester.takeException(), isNull);
      tester.view.viewInsets = const FakeViewPadding(bottom: 200);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result, false);
      expect(find.byType(LogoutConfirmationDialog), findsNothing);
      expect(find.byType(BackdropFilter), findsNothing);
    });
  }
}
