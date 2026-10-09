import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:pikzen/core/services/firestore_service.dart';
import 'package:pikzen/core/services/message_service.dart';
import 'package:pikzen/core/services/order_service.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/shop_management/models/availability_item.dart';
import 'package:pikzen/features/shop_management/models/mock_inventory_item.dart';
import 'package:pikzen/features/shop_management/models/mock_order_details.dart';
import 'package:pikzen/features/shop_management/models/shop_insights.dart';
import 'package:pikzen/features/shop_management/screens/shop_dashboard_screen.dart';
import 'package:pikzen/features/shop_management/screens/product_management_screen.dart';
import 'package:pikzen/features/shop_management/screens/inventory_stock_screen.dart';
import 'package:pikzen/features/shop_management/screens/incoming_orders_screen.dart';
import 'package:pikzen/features/shop_management/screens/order_details_screen.dart';
import 'package:pikzen/features/shop_management/screens/confirm_availability_screen.dart';
import 'package:pikzen/features/shop_management/screens/update_order_status_screen.dart';
import 'package:pikzen/features/shop_management/screens/contact_customer_screen.dart';
import 'package:pikzen/features/shop_management/screens/add_edit_product_screen.dart';
import 'package:pikzen/features/shop_management/widgets/message_composer.dart';
import 'package:pikzen/models/cart_item_model.dart';
import 'package:pikzen/models/message_model.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/product_model.dart';

class _Messages extends MessageService {
  _Messages(this.items);
  final List<OrderMessage> items;
  final sent = <String, String>{};
  @override
  String? get currentUserId => 'shop-1';
  @override
  Stream<List<OrderMessage>> watch(String orderId) => Stream.value(items);
  @override
  Future<void> send(String orderId, String text) async => sent[orderId] = text;
}

class _Products extends FirestoreService {
  _Products(this.items);
  List<ProductModel> items;
  Map<String, int>? savedStock;
  String? savedName;
  @override
  Stream<List<ProductModel>> shopProducts() => Stream.value(items);
  @override
  Future<String> approvedShopUid() async => 'shop-1';
  @override
  Stream<Map<String, dynamic>> approvedShopProfile() => Stream.value({
    'uid': 'shop-1',
    'fullName': 'My Shop',
    'shopName': 'My Shop',
    'role': 'shop',
    'approvalStatus': 'approved',
  });
  @override
  Future<List<ProductModel>> currentProducts() async => items;
  @override
  Future<void> updateShopStocks(Map<String, int> quantities) async {
    savedStock = Map.of(quantities);
  }

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
    savedName = name;
    return ProductModel(
      id: productId ?? 'new',
      name: name,
      priceMinor: priceMinor,
      currencyCode: 'LKR',
      stockQuantity: stockQuantity,
      shopId: 'shop-1',
    );
  }
}

class _Orders extends OrderService {
  _Orders(this.items);
  final List<OrderModel> items;
  String? lastStatus;
  String? rejectedId;
  @override
  Stream<List<OrderModel>> forShop() => Stream.value(items);
  @override
  Future<void> updateOrderStatus({
    required String orderId,
    required String status,
  }) async {
    lastStatus = status;
  }

  @override
  Future<void> rejectShopOrder(String orderId) async {
    rejectedId = orderId;
  }
}

void main() {
  const apples = ProductModel(
    id: 'live-apples',
    name: 'Red Apples',
    priceMinor: 95000,
    currencyCode: 'LKR',
    category: 'Fruits',
    stockQuantity: 20,
    lowStockThreshold: 5,
    shopId: 'shop-1',
  );
  OrderModel order(String status) => OrderModel(
    id: 'order-1',
    userId: 'customer-1',
    items: [const CartItemModel(product: apples, quantity: 1)],
    createdAt: DateTime(2026, 10, 4),
    pickupAt: DateTime(2026, 10, 5, 10),
    status: status,
    shopId: 'shop-1',
    paymentStatus: 'unpaid',
    replacementPreference: 'contactMe',
  );

  test('live product can enter cart and updates propagate', () {
    final cart = CartProvider();
    addTearDown(cart.dispose);
    cart.syncProducts([apples]);
    expect(cart.add(apples), isTrue);
    expect(cart.totalMinor, 95000);

    const low = ProductModel(
      id: 'live-apples',
      name: 'Red Apples',
      priceMinor: 99000,
      currencyCode: 'LKR',
      category: 'Fruits',
      stockQuantity: 5,
      lowStockThreshold: 5,
      shopId: 'shop-1',
    );
    cart.syncProducts([low]);
    expect(cart.totalMinor, 99000);
    expect(cart.items.single.product.stock, StockStatus.lowStock);
    expect(MockInventoryItem.fromProduct(low).status, 'Low Stock');

    const empty = ProductModel(
      id: 'live-apples',
      name: 'Red Apples',
      priceMinor: 99000,
      currencyCode: 'LKR',
      category: 'Fruits',
      stockQuantity: 0,
      lowStockThreshold: 5,
      shopId: 'shop-1',
    );
    cart.syncProducts([empty]);
    expect(cart.items, isEmpty);
    expect(MockInventoryItem.fromProduct(empty).status, 'Out of Stock');
  });

  test('acceptance validation rejects deactivated products', () {
    const inactive = ProductModel(
      id: 'live-apples',
      name: 'Red Apples',
      priceMinor: 95000,
      currencyCode: 'LKR',
      stockQuantity: 20,
      shopId: 'shop-1',
      isActive: false,
    );
    expect(
      () => OrderService.validateCurrentProduct(
        const CartItemModel(product: apples, quantity: 1),
        inactive,
        shopId: 'shop-1',
      ),
      throwsA(isA<OrderActionException>()),
    );
    const item = MockOrderItem(
      name: 'Red Apples',
      quantity: 2,
      type: OrderItemType.apple,
      productId: 'live-apples',
      unitPriceMinor: 95000,
    );
    expect(
      AvailabilityItem.fromOrderItem(item, current: apples).isAvailable,
      isTrue,
    );
    expect(
      AvailabilityItem.fromOrderItem(item, current: inactive).isAvailable,
      isFalse,
    );
  });

  testWidgets('dashboard shows counts from shared product and order data', (
    tester,
  ) async {
    final placed = order('placed');
    await tester.pumpWidget(
      MaterialApp(
        home: ShopDashboardScreen(
          products: _Products([apples]),
          orders: _Orders([placed]),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('My Shop •'), findsOneWidget);
    expect(find.text('1'), findsNWidgets(2));
    expect(find.text('All items well stocked'), findsOneWidget);
    expect(find.text('Review 1 new order'), findsOneWidget);
    expect(find.text('Respond to customer queries'), findsOneWidget);
    expect(find.text('View Stats'), findsOneWidget);
    expect(find.text('GreenMart • Tue, 12 Dec 2024'), findsNothing);
    expect(
      find.textContaining('My Shop • ${formatShopDay(DateTime.now())}'),
      findsOneWidget,
    );
  });

  for (final width in [360.0, 430.0]) {
    testWidgets('live dashboard fits a $width px phone', (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: ShopDashboardScreen(
            products: _Products([apples]),
            orders: _Orders([order('placed')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(greetingFor(DateTime.now())), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'product list displays only injected live products and searches them',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ProductsScreen(service: _Products([apples]))),
      );
      await tester.pumpAndSettle();
      expect(find.text('Red Apples'), findsOneWidget);
      expect(find.text('Fresh Milk'), findsNothing);
      await tester.enterText(find.byType(TextField), 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No products found'), findsOneWidget);
    },
  );

  testWidgets('inventory saves changes against the live product ID', (
    tester,
  ) async {
    final service = _Products([apples]);
    await tester.pumpWidget(
      MaterialApp(home: InventoryStockScreen(service: service)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Decrease Red Apples'));
    await tester.pump();
    await tester.tap(find.text('Update Stock'));
    await tester.pumpAndSettle();
    expect(service.savedStock, {'live-apples': 19});
  });

  testWidgets(
    'incoming orders use placed and scheduled records from the shared service',
    (tester) async {
      final service = _Orders([
        order('placed'),
        OrderModel(
          id: 'order-2',
          userId: 'customer-2',
          items: [const CartItemModel(product: apples, quantity: 1)],
          createdAt: DateTime(2026, 10, 4),
          status: 'accepted',
          shopId: 'shop-1',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(home: IncomingOrdersScreen(orderService: service)),
      );
      await tester.pumpAndSettle();
      expect(find.text('#order-1'), findsOneWidget);
      expect(find.text('#order-2'), findsNothing);
      await tester.tap(find.text('Scheduled'));
      await tester.pumpAndSettle();
      expect(find.text('#order-2'), findsOneWidget);
      expect(find.text('#order-1'), findsNothing);
    },
  );

  testWidgets('order details display the selected order snapshot', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OrderDetailsScreen(
          order: MockOrderDetails.fromOrder(order('placed')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Red Apples'), findsOneWidget);
    expect(find.textContaining('Customer ID: customer-1'), findsOneWidget);
    expect(find.textContaining('Payment: unpaid'), findsOneWidget);
  });

  testWidgets(
    'availability compares ordered quantity with current live stock',
    (tester) async {
      final details = MockOrderDetails.fromOrder(order('placed'));
      await tester.pumpWidget(
        MaterialApp(
          home: ConfirmAvailabilityScreen(
            order: details,
            products: _Products([apples]),
            orders: _Orders([order('placed')]),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Red Apples'), findsOneWidget);
      expect(find.text('In Stock'), findsOneWidget);
      expect(find.textContaining('contactMe'), findsOneWidget);
    },
  );

  testWidgets('status action uses the shared order service', (tester) async {
    final service = _Orders([order('accepted')]);
    await tester.pumpWidget(
      MaterialApp(
        home: UpdateOrderStatusScreen(
          order: MockOrderDetails.fromOrder(order('accepted')),
          orderService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start Preparing'));
    await tester.pumpAndSettle();
    expect(service.lastStatus, 'preparing');
  });

  testWidgets('contact screen shows live messages and sends to the order', (
    tester,
  ) async {
    final messages = _Messages(const [
      OrderMessage(
        id: 'm1',
        senderId: 'customer-1',
        senderRole: 'customer',
        text: 'Is the milk chilled?',
      ),
    ]);
    final details = MockOrderDetails.fromOrder(order('placed'));
    await tester.pumpWidget(
      MaterialApp(
        home: ContactCustomerScreen(order: details, messages: messages),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Is the milk chilled?'), findsOneWidget);
    expect(
      tester.widget<MessageComposer>(find.byType(MessageComposer)).onSend,
      isNotNull,
    );
    await tester.enterText(find.byType(TextField), 'Yes, ready at 10.');
    await tester.tap(find.byTooltip('Send message'));
    await tester.pumpAndSettle();
    expect(messages.sent, {details.orderId.substring(1): 'Yes, ready at 10.'});
  });

  testWidgets('product form validates and sends live values to the service', (
    tester,
  ) async {
    final service = _Products([]);
    final router = GoRouter(
      initialLocation: '/add',
      routes: [
        GoRoute(
          path: '/add',
          builder: (context, state) => AddEditProductScreen(service: service),
        ),
        GoRoute(
          path: '/products',
          name: 'product-management',
          builder: (context, state) =>
              const Scaffold(body: Text('Products saved')),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Product').last);
    await tester.tap(find.text('Add Product').last);
    await tester.pumpAndSettle();
    expect(find.text('Enter a product name'), findsOneWidget);
    expect(service.savedName, isNull);
    await tester.enterText(find.byType(TextFormField).at(0), 'Red Apples');
    await tester.enterText(find.byType(TextFormField).at(1), '950');
    await tester.ensureVisible(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Fruits').last);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Add Product').last);
    await tester.tap(find.text('Add Product').last);
    await tester.pumpAndSettle();
    expect(service.savedName, 'Red Apples');
    expect(find.text('Products saved'), findsOneWidget);
  });
}
