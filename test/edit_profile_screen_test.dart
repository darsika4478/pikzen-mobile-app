import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/router/app_router.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/cart_checkout/providers/cart_provider.dart';
import 'package:pikzen/features/product_discovery/providers/product_provider.dart';
import 'package:pikzen/features/profile/screens/edit_profile_screen.dart';
import 'package:pikzen/features/profile/screens/profile_screen.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/user_model.dart';

import 'auth_test_support.dart';

const _identity = (
  uid: 'test-user',
  email: 'auth@example.com',
  displayName: 'Auth Name',
  photoUrl: null,
  emailVerified: true,
);

class _ProfileStore {
  Map<String, dynamic>? document = {
    'uid': 'test-user',
    'role': 'customer',
    'approvalStatus': 'legacy',
    'accountStatus': 'active',
    'fullName': 'Nimal Silva',
    'email': 'old-firestore@example.com',
    'phone': '+94771234567',
    'createdAt': Timestamp.fromDate(DateTime.utc(2023, 6, 1)),
    'preferences': {
      'readyForPickupSms': true,
      'paperlessInvoices': false,
      'quietHours': true,
    },
  };
  final writes = <Map<String, Object?>>[];
  bool failOnce = false;
  Completer<void>? gate;

  Future<void> save(String uid, Map<String, Object?> changes) async {
    if (uid != 'test-user') throw StateError('Wrong customer.');
    writes.add(Map.of(changes));
    if (failOnce) {
      failOnce = false;
      throw StateError('Offline test failure.');
    }
    if (gate != null) await gate!.future;
    final saved = document!;
    for (final entry in changes.entries) {
      if (entry.key.startsWith('preferences.')) {
        final preferences = Map<String, dynamic>.from(
          saved['preferences'] as Map? ?? const {},
        );
        preferences[entry.key.substring('preferences.'.length)] = entry.value;
        saved['preferences'] = preferences;
      } else {
        saved[entry.key] = entry.value;
      }
    }
  }
}

class _ProfileAuthService extends FakeAuthService {
  _ProfileAuthService(this.store);
  final _ProfileStore store;

  @override
  Future<UserModel> profile() async {
    final document = store.document!;
    return UserModel.fromMap('test-user', document);
  }
}

Future<({GoRouter router, AuthProvider auth})> _mount(
  WidgetTester tester,
  _ProfileStore store, {
  EditProfileIdentity identity = _identity,
  Future<Map<String, dynamic>?> Function(String)? loader,
  Stream<List<OrderModel>> Function(String)? orders,
  double textScale = 1,
  bool waitForReady = true,
}) async {
  final auth = AuthProvider(service: _ProfileAuthService(store), restore: false);
  expect(await auth.signIn('test@example.com', 'password'), isTrue);
  final products = ProductProvider();
  final router = GoRouter(
    initialLocation: '/edit-profile',
    routes: [
      GoRoute(
        path: '/edit-profile',
        name: 'edit-profile',
        builder: (_, _) => EditProfileScreen(
          identityForTesting: identity,
          profileLoader: loader ?? (_) async => store.document,
          profileWriter: store.save,
          ordersForCustomer: orders ?? (_) => Stream.value(const []),
        ),
      ),
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (_, _) => ProfileScreen(
          profileDocuments: (_) => Stream.value(store.document),
          ordersForCustomer: (_) => Stream.value(const []),
        ),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  addTearDown(products.dispose);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider<ProductProvider>.value(value: products),
    ],
    child: MaterialApp.router(
      theme: AppTheme.lightTheme,
      routerConfig: router,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
    ),
  ));
  if (waitForReady) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (router: router, auth: auth);
}

Future<void> _tapSave(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.pumpAndSettle();
  final button = find.widgetWithText(FilledButton, 'Save Changes');
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('loads the signed-in customer and shows only verified Auth email',
      (tester) async {
    final store = _ProfileStore();
    final loaded = Completer<Map<String, dynamic>?>();
    String? requestedUid;
    final mounting = _mount(tester, store, waitForReady: false, loader: (uid) {
      requestedUid = uid;
      return loaded.future;
    });
    // _mount waits for scheduled frames, not for the delayed profile load.
    await mounting;
    expect(requestedUid, 'test-user');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    loaded.complete(store.document);
    await tester.pumpAndSettle();
    expect(find.text('Nimal Silva'), findsWidgets);
    expect(find.text('Member since 2023'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('fullName')))
        .controller!.text, 'Nimal Silva');
    final email = tester.widget<TextFormField>(find.byKey(const ValueKey('email')));
    expect(email.initialValue, 'auth@example.com');
    expect(tester.widget<TextField>(find.descendant(
      of: find.byKey(const ValueKey('email')),
      matching: find.byType(TextField),
    )).readOnly, isTrue);
    expect(find.text('Verified'), findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('phone')))
        .controller!.text, '+94771234567');
    expect(find.text('Phone Number'), findsOneWidget);
    expect(find.text('Required'), findsOneWidget);
  });

  testWidgets('missing optional data uses initials and no false badges',
      (tester) async {
    final store = _ProfileStore();
    store.document = {
      'uid': 'test-user',
      'role': 'customer',
      'fullName': '',
      'phone': null,
    };
    await _mount(tester, store, identity: (
      uid: 'test-user',
      email: 'auth@example.com',
      displayName: 'Auth Name',
      photoUrl: null,
      emailVerified: false,
    ));
    expect(find.text('Auth Name'), findsOneWidget);
    expect(find.text('AN'), findsOneWidget);
    expect(find.text('Verified'), findsNothing);
    expect(find.text('Member since 2023'), findsNothing);
    expect(find.text('Default Hub'), findsNothing);
    expect(find.text('SMS Alerts Enabled'), findsNothing);
    expect(tester.widget<IconButton>(find.widgetWithIcon(
      IconButton, Icons.camera_alt_outlined,
    ))
        .onPressed, isNull);
    expect(tester.widget<IconButton>(find.widgetWithIcon(
      IconButton, Icons.delete_outline,
    ))
        .onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses a real recent order hub and disables unavailable Change',
      (tester) async {
    final store = _ProfileStore();
    await _mount(tester, store, orders: (_) => Stream.value([
      OrderModel(
        id: 'order-1',
        userId: 'test-user',
        items: const [],
        createdAt: DateTime.utc(2026, 10, 1),
        shopName: 'Colombo 03 Hub',
      ),
    ]));
    expect(find.text('Colombo 03 Hub'), findsOneWidget);
    expect(find.text('From a recent order • No saved default hub'),
        findsOneWidget);
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Change'))
        .onPressed, isNull);
  });

  testWidgets('saves only changed safe fields and refreshes existing Profile',
      (tester) async {
    final store = _ProfileStore();
    final result = await _mount(tester, store);
    await tester.enterText(find.byKey(const ValueKey('fullName')), '  Maya Perera  ');
    await tester.enterText(find.byKey(const ValueKey('phone')), '077 888 9999');
    await tester.ensureVisible(find.text('Order Ready for Pickup SMS'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Order Ready for Pickup SMS'));
    await tester.ensureVisible(find.text('Paperless Digital Invoices'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Paperless Digital Invoices'));
    await _tapSave(tester);
    expect(store.writes, hasLength(1));
    expect(store.writes.single, {
      'fullName': 'Maya Perera',
      'phone': '+94778889999',
      'preferences.readyForPickupSms': false,
      'preferences.paperlessInvoices': true,
    });
    expect((store.document!['preferences'] as Map)['quietHours'], isTrue);
    expect(store.document!['uid'], 'test-user');
    expect(store.document!['role'], 'customer');
    expect(store.document!['approvalStatus'], 'legacy');
    expect(store.document!['accountStatus'], 'active');
    expect(store.document!['email'], 'old-firestore@example.com');
    expect(store.document!['createdAt'], isA<Timestamp>());
    expect(result.auth.user?.name, 'Maya Perera');
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(find.text('Maya Perera'), findsOneWidget);
    expect(find.text('+94778889999'), findsOneWidget);
    result.router.goNamed('edit-profile');
    await tester.pumpAndSettle();
    expect(tester.widget<SwitchListTile>(find.widgetWithText(
      SwitchListTile,
      'Order Ready for Pickup SMS',
    )).value, isFalse);
    expect(tester.widget<SwitchListTile>(find.widgetWithText(
      SwitchListTile,
      'Paperless Digital Invoices',
    )).value, isTrue);
  });

  testWidgets('rejects whitespace names and invalid Sri Lankan phone numbers',
      (tester) async {
    final store = _ProfileStore();
    await _mount(tester, store);
    await tester.enterText(find.byKey(const ValueKey('fullName')), '   ');
    await tester.enterText(find.byKey(const ValueKey('phone')), '123');
    await _tapSave(tester);
    expect(find.text('Enter your full name'), findsOneWidget);
    expect(find.text('Enter a valid Sri Lankan mobile number'), findsOneWidget);
    expect(store.writes, isEmpty);
    expect(find.byType(EditProfileScreen), findsOneWidget);
  });

  testWidgets('discard restores loaded values without writing', (tester) async {
    final store = _ProfileStore();
    await _mount(tester, store);
    await tester.enterText(find.byKey(const ValueKey('fullName')), 'Changed Name');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final discard = find.widgetWithText(TextButton, 'Discard Unsaved Changes');
    await tester.ensureVisible(discard);
    await tester.pumpAndSettle();
    await tester.tap(discard);
    await tester.pumpAndSettle();
    expect(find.text('Discard changes?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('fullName')))
        .controller!.text, 'Changed Name');
    await tester.tap(discard);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('fullName')))
        .controller!.text, 'Nimal Silva');
    expect(store.writes, isEmpty);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton,
        'Save Changes')).onPressed, isNull);
  });

  testWidgets('back warns for edits, then leaves when unchanged', (tester) async {
    final store = _ProfileStore();
    await _mount(tester, store);
    await tester.enterText(find.byKey(const ValueKey('fullName')), 'Maya Perera');
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Discard unsaved changes?'), findsOneWidget);
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();
    expect(find.byType(ProfileScreen), findsOneWidget);
    expect(store.writes, isEmpty);
  });

  testWidgets('duplicate save taps create one write', (tester) async {
    final store = _ProfileStore();
    store.gate = Completer<void>();
    await _mount(tester, store);
    await tester.enterText(find.byKey(const ValueKey('fullName')), 'Maya Perera');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final save = find.widgetWithText(FilledButton, 'Save Changes');
    await tester.ensureVisible(save);
    await tester.pumpAndSettle();
    await tester.tap(save);
    await tester.tap(save, warnIfMissed: false);
    await tester.pump();
    expect(store.writes, hasLength(1));
    expect(find.text('Saving...'), findsOneWidget);
    store.gate!.complete();
    await tester.pumpAndSettle();
    expect(store.writes, hasLength(1));
  });

  testWidgets('failed save keeps edits and permits retry', (tester) async {
    final store = _ProfileStore()..failOnce = true;
    await _mount(tester, store);
    await tester.enterText(find.byKey(const ValueKey('fullName')), 'Maya Perera');
    await _tapSave(tester);
    expect(find.text('Could not save changes. Please try again.'),
        findsOneWidget);
    expect(tester.widget<TextFormField>(find.byKey(const ValueKey('fullName')))
        .controller!.text, 'Maya Perera');
    expect(find.byType(EditProfileScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await _tapSave(tester);
    expect(store.writes, hasLength(2));
    expect(find.byType(ProfileScreen), findsOneWidget);
  });

  testWidgets('missing customer document cannot create an incomplete user',
      (tester) async {
    final store = _ProfileStore()..document = null;
    await _mount(tester, store);
    expect(find.text('Your customer profile is unavailable.'), findsOneWidget);
    expect(find.text('Save Changes'), findsNothing);
    expect(store.writes, isEmpty);
  });

  testWidgets('existing shell keeps Profile selected on Edit Profile',
      (tester) async {
    final store = _ProfileStore();
    final auth = AuthProvider(service: _ProfileAuthService(store), restore: false);
    expect(await auth.signIn('test@example.com', 'password'), isTrue);
    final products = ProductProvider();
    final cart = CartProvider();
    addTearDown(auth.dispose);
    addTearDown(products.dispose);
    addTearDown(cart.dispose);
    appRouter.goNamed('edit-profile');
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: auth),
        ChangeNotifierProvider<ProductProvider>.value(value: products),
        ChangeNotifierProvider<CartProvider>.value(value: cart),
      ],
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: appRouter,
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(EditProfileScreen), findsOneWidget);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar))
        .selectedIndex, 4);
  });

  testWidgets('small phone and keyboard retain scroll access to Save Changes',
      (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = _ProfileStore();
    await _mount(tester, store, textScale: 1.6);
    await tester.enterText(find.byKey(const ValueKey('phone')), '0771234567');
    await tester.showKeyboard(find.byKey(const ValueKey('phone')));
    await tester.ensureVisible(find.text('Save Changes'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
