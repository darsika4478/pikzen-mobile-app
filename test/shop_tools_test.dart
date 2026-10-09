import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pikzen/core/services/auth_service.dart';
import 'package:pikzen/core/services/firestore_service.dart';
import 'package:pikzen/features/profile/screens/change_password_screen.dart';
import 'package:pikzen/features/shop_management/models/shop_insights.dart';
import 'package:pikzen/features/shop_management/screens/add_edit_product_screen.dart';
import 'package:pikzen/features/shop_management/screens/shop_reports_screen.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

const _apples = ProductModel(
  id: 'apples',
  name: 'Apples',
  priceMinor: 50000,
  currencyCode: 'LKR',
);
const _milk = ProductModel(
  id: 'milk',
  name: 'Milk',
  priceMinor: 20000,
  currencyCode: 'LKR',
);

OrderModel _order(
  String id,
  DateTime at,
  String status, {
  String method = 'card',
  List<CartItemModel> items = const [
    CartItemModel(product: _apples, quantity: 2),
  ],
}) => OrderModel(
  id: id,
  userId: 'c',
  items: items,
  createdAt: at,
  pickupAt: at.add(const Duration(hours: 2)),
  status: status,
  paymentMethod: method,
);

class _Products extends FirestoreService {
  String? savedImage;
  String? savedUnit;
  String? savedCategory;

  @override
  Future<ProductModel> saveShopProduct({
    String? productId,
    required String name,
    required String category,
    required int priceMinor,
    required int stockQuantity,
    String description = '',
    String unit = '',
    String? imageUrl,
    int lowStockThreshold = 5,
  }) async {
    savedImage = imageUrl;
    savedUnit = unit;
    savedCategory = category;
    return ProductModel(
      id: 'new',
      name: name,
      priceMinor: priceMinor,
      currencyCode: 'LKR',
    );
  }
}

class _Auth extends AuthService {
  String? changedTo;
  bool wrongCurrent = false;

  @override
  Future<void> changePassword(
    String currentPassword,
    String newPassword,
  ) async {
    if (wrongCurrent) {
      throw const AuthFailure('Your current password is incorrect.');
    }
    changedTo = newPassword;
  }
}

void main() {
  group('shop report', () {
    final now = DateTime(2026, 10, 9, 15);

    test('counts sales, excludes cancelled orders and ranks products', () {
      final report = ShopReport.from(
        [
          _order('a', DateTime(2026, 10, 9, 9), 'collected'),
          _order(
            'b',
            DateTime(2026, 10, 8, 9),
            'placed',
            method: 'cashOnPickup',
            items: const [CartItemModel(product: _milk, quantity: 1)],
          ),
          _order('c', DateTime(2026, 10, 9, 11), 'cancelled'),
          _order('old', DateTime(2026, 9, 1), 'collected'),
        ],
        now: now,
        days: 7,
      );
      expect(report.orders, 2);
      expect(report.salesMinor, 120000);
      expect(report.completed, 1);
      expect(report.averageMinor, 60000);
      expect(report.statusCounts['cancelled'], 1);
      expect(report.topProducts.first.name, 'Apples');
      expect(report.paymentCounts, {'card': 1, 'cashOnPickup': 1});
      expect(report.daily.last, 100000);
      expect(report.daily.length, 7);
    });

    test('today only counts orders placed today', () {
      final report = ShopReport.from(
        [
          _order('a', DateTime(2026, 10, 9, 9), 'collected'),
          _order('b', DateTime(2026, 10, 8, 9), 'collected'),
        ],
        now: now,
        days: 1,
      );
      expect(report.orders, 1);
    });
  });

  test('shop alerts list new orders, waiting chats and stock issues', () {
    final alerts = shopAlerts(
      orders: [
        _order('new', DateTime(2026, 10, 9), 'placed'),
        _order('chat', DateTime(2026, 10, 9), 'preparing'),
      ],
      products: const [
        ProductModel(
          id: 'low',
          name: 'Low',
          priceMinor: 1,
          currencyCode: 'LKR',
          stockQuantity: 2,
        ),
        ProductModel(
          id: 'out',
          name: 'Out',
          priceMinor: 1,
          currencyCode: 'LKR',
          stockQuantity: 0,
        ),
      ],
      awaitingReply: {'chat'},
    );
    expect(alerts.map((a) => a.kind), [
      ShopAlertKind.newOrder,
      ShopAlertKind.customerMessage,
      ShopAlertKind.outOfStock,
      ShopAlertKind.lowStock,
    ]);
    final muted = enabledShopAlerts(alerts, {
      'preferences': {'lowStockAlerts': false},
    });
    expect(muted.length, 2);
  });

  test('store status follows pickup hours', () {
    expect(storeStatusAt(DateTime(2026, 10, 9, 10)).open, isTrue);
    expect(storeStatusAt(DateTime(2026, 10, 9, 21)).open, isFalse);
    expect(formatShopDay(DateTime(2026, 10, 9)), 'Fri, 9 Oct 2026');
  });

  testWidgets('new product saves an uploaded photo, unit and real category', (
    tester,
  ) async {
    final service = _Products();
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/add',
          builder: (_, _) => AddEditProductScreen(
            service: service,
            photoPicker: (source) async {
              expect(source, ImageSource.gallery);
              return Uint8List.fromList([0xFF, 0xD8, 0xFF, 0xD9]);
            },
          ),
        ),
        GoRoute(
          path: '/products',
          name: 'product-management',
          builder: (_, _) => const Scaffold(body: Text('Products saved')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Add Photo'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Choose from Gallery'));
    await tester.pumpAndSettle();
    expect(find.text('Remove photo'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).at(0), 'Mangoes');
    await tester.enterText(find.byType(TextFormField).at(1), '450');
    await tester.enterText(find.byType(TextFormField).at(2), '1kg bag');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pantry Staples').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Product').last);
    await tester.tap(find.text('Add Product').last);
    await tester.pumpAndSettle();
    expect(service.savedImage, startsWith('data:image/jpeg;base64,'));
    expect(service.savedUnit, '1kg bag');
    expect(service.savedCategory, 'Pantry Staples');
  });

  testWidgets('change password validates, reports errors and saves', (
    tester,
  ) async {
    final auth = _Auth()..wrongCurrent = true;
    await tester.pumpWidget(
      MaterialApp(
        home: ChangePasswordScreen(
          service: auth,
          emailForTesting: 'shop@example.com',
          hasPasswordForTesting: true,
        ),
      ),
    );
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'OldPassword1');
    await tester.enterText(fields.at(1), 'NewPassword1');
    await tester.enterText(fields.at(2), 'Mismatch');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Passwords do not match'), findsOneWidget);
    expect(auth.changedTo, isNull);
    await tester.enterText(fields.at(2), 'NewPassword1');
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(find.text('Your current password is incorrect.'), findsOneWidget);
    auth.wrongCurrent = false;
    await tester.tap(find.text('Update Password'));
    await tester.pumpAndSettle();
    expect(auth.changedTo, 'NewPassword1');
  });
}
