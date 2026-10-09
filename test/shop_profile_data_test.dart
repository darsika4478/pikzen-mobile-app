import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/services/firestore_service.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/features/profile/widgets/merchant_edit_profile_view.dart';
import 'package:pikzen/features/profile/widgets/merchant_profile_view.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

class _ShopProfileService extends FirestoreService {
  final profile = <String, dynamic>{
    'uid': 'shop-1',
    'role': 'shop',
    'approvalStatus': 'approved',
    'fullName': 'Test Owner',
    'shopName': 'Orchard Shop',
    'phone': '0712345678',
    'email': 'owner@example.com',
    'storeAddress': 'Main Street',
  };
  Map<String, String>? saved;

  @override
  Stream<Map<String, dynamic>> approvedShopProfile() => Stream.value(profile);
  @override
  Stream<List<ProductModel>> shopProducts() => Stream.value(const [
    ProductModel(
      id: 'apple',
      name: 'Apples',
      priceMinor: 95000,
      currencyCode: 'LKR',
      shopId: 'shop-1',
      stockQuantity: 20,
    ),
  ]);
  @override
  Future<void> updateShopProfile({
    required String phone,
    required String shopName,
    required String storeAddress,
  }) async {
    saved = {
      'phone': phone,
      'shopName': shopName,
      'storeAddress': storeAddress,
    };
  }
}

class _ShopOrders extends OrderService {
  @override
  Stream<List<OrderModel>> forShop() => Stream.value([
    OrderModel(
      id: 'order-1',
      userId: 'customer-1',
      items: [],
      createdAt: DateTime(2026, 10, 4),
      status: 'placed',
      shopId: 'shop-1',
    ),
  ]);
}

void main() {
  for (final width in [360.0, 430.0]) {
    testWidgets('live merchant profile fits a $width px phone', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MerchantProfileView(
            products: _ShopProfileService(),
            orders: _ShopOrders(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Orchard Shop'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('merchant profile displays current shop and live counts', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MerchantProfileView(
          products: _ShopProfileService(),
          orders: _ShopOrders(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Orchard Shop'), findsOneWidget);
    expect(find.text('Approved Shop • ID: shop-1'), findsOneWidget);
    expect(find.text('1 New'), findsOneWidget);
    expect(find.text('1 Items'), findsOneWidget);
    expect(find.text('GreenMart'), findsNothing);
  });

  testWidgets(
    'merchant editor loads real fields and updates safe profile fields only',
    (tester) async {
      final service = _ShopProfileService();
      final router = GoRouter(
        initialLocation: '/edit',
        routes: [
          GoRoute(
            path: '/edit',
            builder: (context, state) =>
                MerchantEditProfileView(service: service),
          ),
          GoRoute(
            path: '/profile',
            name: 'shop-profile',
            builder: (context, state) =>
                const Scaffold(body: Text('Profile saved')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(MaterialApp.router(routerConfig: router));
      await tester.pumpAndSettle();
      final fields = find.byType(TextFormField);
      expect(
        tester.widget<TextFormField>(fields.first).controller!.text,
        'Orchard Shop',
      );
      expect(
        tester.widget<TextFormField>(fields.at(2)).controller!.text,
        'owner@example.com',
      );
      final emailField = tester.widget<TextField>(
        find.descendant(of: fields.at(2), matching: find.byType(TextField)),
      );
      expect(emailField.readOnly, isTrue);
      await tester.enterText(fields.first, 'New Shop');
      await tester.ensureVisible(find.text('Save Changes'));
      await tester.tap(find.text('Save Changes'));
      await tester.pumpAndSettle();
      expect(service.saved, {
        'phone': '0712345678',
        'shopName': 'New Shop',
        'storeAddress': 'Main Street',
      });
      expect(find.text('Profile saved'), findsOneWidget);
    },
  );
}
