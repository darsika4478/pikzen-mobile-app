import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/core/theme/app_scroll_behavior.dart';

void main() {
  for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
    testWidgets(
      'scrolling stays bounded on $platform without moving the footer',
      (tester) async {
        final vertical = ScrollController();
        final horizontal = ScrollController();
        addTearDown(vertical.dispose);
        addTearDown(horizontal.dispose);

        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData(useMaterial3: true, platform: platform),
            scrollBehavior: const AppScrollBehavior(),
            home: Scaffold(
              body: SingleChildScrollView(
                controller: vertical,
                child: Column(
                  children: [
                    const SizedBox(key: Key('card'), height: 120),
                    SizedBox(
                      height: 60,
                      child: ListView(
                        controller: horizontal,
                        scrollDirection: Axis.horizontal,
                        children: List.generate(
                          10,
                          (index) => const SizedBox(width: 120),
                        ),
                      ),
                    ),
                    const SizedBox(height: 1400),
                  ],
                ),
              ),
              bottomNavigationBar: const SizedBox(
                key: Key('footer'),
                height: 70,
              ),
            ),
          ),
        );

        final footerBefore = tester.getTopLeft(find.byKey(const Key('footer')));
        final cardHeight = tester.getSize(find.byKey(const Key('card'))).height;
        expect(find.byType(StretchingOverscrollIndicator), findsNothing);
        expect(vertical.position.physics, isA<ClampingScrollPhysics>());

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, 250),
        );
        await tester.pumpAndSettle();
        expect(vertical.offset, 0);

        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -300),
        );
        await tester.pumpAndSettle();
        expect(vertical.offset, greaterThan(0));
        expect(
          tester.getSize(find.byKey(const Key('card'))).height,
          cardHeight,
        );

        vertical.jumpTo(vertical.position.maxScrollExtent);
        await tester.pump();
        await tester.drag(
          find.byType(SingleChildScrollView),
          const Offset(0, -250),
        );
        await tester.pumpAndSettle();
        expect(vertical.offset, vertical.position.maxScrollExtent);
        expect(
          tester.getTopLeft(find.byKey(const Key('footer'))),
          footerBefore,
        );

        vertical.jumpTo(0);
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(horizontal.offset, greaterThan(0));
        expect(tester.takeException(), isNull);
      },
    );
  }
}
