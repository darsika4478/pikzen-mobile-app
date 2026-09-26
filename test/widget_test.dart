import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/app.dart';

void main() {
  testWidgets('PikZen app builds successfully', (WidgetTester tester) async {
    await tester.pumpWidget(const PikZenApp());

    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
