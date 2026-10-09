import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/constants/app_assets.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/shared/screens/onboarding_screen.dart';

void main() {
  Future<GoRouter> mount(WidgetTester tester) async {
    final router = GoRouter(
      initialLocation: '/onboarding',
      routes: [
        GoRoute(
          path: '/onboarding',
          builder: (_, _) => const OnboardingScreen(),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('Login destination')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      MaterialApp.router(theme: AppTheme.lightTheme, routerConfig: router),
    );
    await tester.pumpAndSettle();
    return router;
  }

  Future<void> tap(WidgetTester tester, String label) async {
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  void page(WidgetTester tester, int index) {
    final controller = tester
        .widget<PageView>(find.byType(PageView))
        .controller!;
    expect(controller.page, index.toDouble());
    expect(tester.takeException(), isNull);
  }

  testWidgets('Pages advance only by buttons and finish with replacement', (
    tester,
  ) async {
    final router = await mount(tester);
    for (var i = 0; i < 3; i++) {
      page(tester, i);
      await tester.pump(const Duration(seconds: 90));
      page(tester, i);
      await tester.drag(find.byType(PageView), const Offset(-250, 0));
      await tester.pumpAndSettle();
      page(tester, i);
      if (i < 2) await tap(tester, 'Next');
    }
    await tap(tester, 'Back');
    page(tester, 1);
    await tap(tester, 'Back');
    page(tester, 0);
    await tap(tester, 'Next');
    await tap(tester, 'Next');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    page(tester, 1);
    await tap(tester, 'Next');
    await tap(tester, 'Get Started');
    expect(find.text('Login destination'), findsOneWidget);
    expect(router.canPop(), isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (var index = 0; index < 3; index++) {
    testWidgets('Skip from page ${index + 1} replaces onboarding with login', (
      tester,
    ) async {
      final router = await mount(tester);
      for (var i = 0; i < index; i++) {
        await tap(tester, 'Next');
      }
      await tap(tester, 'Skip');
      expect(find.text('Login destination'), findsOneWidget);
      expect(router.canPop(), isFalse);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }

  testWidgets('Pages fit phone sizes and enlarged text without overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [
      const Size(320, 568),
      const Size(360, 800),
      const Size(390, 844),
      const Size(412, 915),
    ]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.lightTheme,
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: const OnboardingScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 3; i++) {
          page(tester, i);
          expect(
            find.text(i == 2 ? 'Get Started' : 'Next').hitTestable(),
            findsOneWidget,
          );
          if (i < 2) await tap(tester, 'Next');
        }
        await tester.pumpWidget(const SizedBox.shrink());
      }
    }
  });

  testWidgets('All local onboarding images and logo decode', (tester) async {
    await tester.runAsync(() async {
      for (final asset in [
        AppAssets.onboarding1,
        AppAssets.onboarding2,
        AppAssets.onboarding3,
        AppAssets.logo,
      ]) {
        final bytes = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
