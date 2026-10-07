import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/shop_management/screens/shop_dashboard_screen.dart';
import 'package:pikzen/features/shop_management/widgets/dashboard_bottom_nav.dart';

void main() {
  for (final width in [360.0, 375.0, 390.0, 412.0, 430.0]) {
    testWidgets('Dashboard fits at $width px with readable text', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 850);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const ShopDashboardScreen(),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Good Morning!'), findsOneWidget);
      expect(find.text('12'), findsOneWidget);
      expect(find.text('28'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Respond to 2 customer queries'),
        150,
      );
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(DashboardBottomNav)).bottom, 850);
      // Check accessibility text scaling at the narrowest supported size too.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightTheme,
          home: const MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(1.3)),
            child: ShopDashboardScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Preview notification control responds', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const ShopDashboardScreen(),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Notifications'));
    await tester.pump();
    expect(find.text('No new notifications in this preview.'), findsOneWidget);
    expect(
      tester
          .widget<DashboardBottomNav>(find.byType(DashboardBottomNav))
          .selectedIndex,
      0,
    );
    expect(tester.takeException(), isNull);
  });
}
