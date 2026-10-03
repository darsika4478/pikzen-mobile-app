import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pikzen/core/theme/app_theme.dart';
import 'package:pikzen/features/auth/providers/auth_provider.dart';
import 'package:pikzen/features/profile/screens/settings_screen.dart';
import 'package:pikzen/models/order_model.dart';

import 'auth_test_support.dart';

const _passwordIdentity = (
  uid: 'test-user',
  email: 'customer@example.com',
  passwordProvider: true,
  googleOnly: false,
);

class _SettingsStore {
  Map<String, dynamic>? document = {
    'uid': 'test-user',
    'role': 'customer',
    'fullName': 'Real Customer',
    'email': 'customer@example.com',
    'phone': '+94771234567',
    'approvalStatus': 'legacy',
    'accountStatus': 'active',
    'createdAt': 'preserved',
    'preferences': {
      'pushNotifications': true,
      'readyForPickupSms': true,
      'paperlessInvoices': false,
      'quietHours': true,
    },
  };
  final writes = <Map<String, Object?>>[];
  Completer<void>? gate;
  bool failOnce = false;

  Future<void> write(String uid, Map<String, Object?> changes) async {
    expect(uid, 'test-user');
    writes.add(Map.of(changes));
    if (failOnce) {
      failOnce = false;
      throw StateError('Offline');
    }
    if (gate != null) await gate!.future;
    final preferences = Map<String, dynamic>.from(
      document!['preferences'] as Map? ?? const {},
    );
    for (final entry in changes.entries) {
      if (entry.key == 'preferences.pushNotifications') {
        preferences['pushNotifications'] = entry.value;
      }
    }
    document!['preferences'] = preferences;
  }
}

class _SettingsAuthService extends FakeAuthService {
  int signOutCalls = 0;
  bool failReset = false;
  bool failSignOut = false;

  @override
  Future<void> signOut() async {
    signOutCalls++;
    if (failSignOut) throw StateError('Offline');
  }

  @override
  Future<void> resetPassword(String email) async {
    if (failReset) throw StateError('Offline');
    await super.resetPassword(email);
  }
}

Future<({GoRouter router, AuthProvider auth, _SettingsAuthService service})>
_mount(
  WidgetTester tester,
  _SettingsStore store, {
  SettingsIdentity identity = _passwordIdentity,
  Future<Map<String, dynamic>?> Function(String)? loader,
  Stream<List<OrderModel>> Function(String)? orders,
  bool waitForReady = true,
}) async {
  final service = _SettingsAuthService();
  final auth = AuthProvider(service: service, restore: false);
  expect(await auth.signIn('customer@example.com', 'password'), isTrue);
  final router = GoRouter(
    initialLocation: '/profile',
    routes: [
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (_, _) => Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => context.pushNamed('settings'),
              child: const Text('Open Settings'),
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/settings',
        name: 'settings',
        builder: (_, _) => SettingsScreen(
          identityForTesting: identity,
          profileLoader: loader ?? (_) async => store.document,
          profileWriter: store.write,
          ordersForCustomer: orders ?? (_) => Stream.value(const []),
        ),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (_, _) => const Scaffold(body: Text('Common Login')),
      ),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(auth.dispose);
  await tester.pumpWidget(
    ChangeNotifierProvider<AuthProvider>.value(
      value: auth,
      child: MaterialApp.router(
        theme: AppTheme.lightTheme,
        routerConfig: router,
      ),
    ),
  );
  await tester.tap(find.text('Open Settings'));
  if (waitForReady) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }
  return (router: router, auth: auth, service: service);
}

Future<void> _tapRow(WidgetTester tester, String title) async {
  final row = find.widgetWithText(ListTile, title);
  await tester.ensureVisible(row);
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'loads Settings and handles a delayed profile without sample data',
    (tester) async {
      final store = _SettingsStore();
      final pending = Completer<Map<String, dynamic>?>();
      String? requestedUid;
      await _mount(
        tester,
        store,
        waitForReady: false,
        loader: (uid) {
          requestedUid = uid;
          return pending.future;
        },
      );
      expect(requestedUid, 'test-user');
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete(store.document);
      await tester.pumpAndSettle();
      expect(find.text('App Settings'), findsOneWidget);
      expect(find.text('PREFERENCES'), findsOneWidget);
      expect(find.text('ACCOUNT & SECURITY'), findsOneWidget);
      expect(find.text('SUPPORT & LEGAL'), findsOneWidget);
      expect(find.text('SESSION ACTION'), findsOneWidget);
      expect(find.text('No pickup hub selected'), findsOneWidget);
      expect(find.text('Colombo Central Hub'), findsNothing);
      expect(find.text('Enabled'), findsNothing);
      expect(find.text('Not configured'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.textContaining('locker'), findsNothing);
    },
  );

  testWidgets('Back returns to existing Profile route', (tester) async {
    final result = await _mount(tester, _SettingsStore());
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(result.router.routeInformationProvider.value.uri.path, '/profile');
    expect(find.text('Open Settings'), findsOneWidget);
  });

  testWidgets('pickup card displays an actual active order location', (
    tester,
  ) async {
    await _mount(
      tester,
      _SettingsStore(),
      orders: (_) => Stream.value([
        OrderModel(
          id: 'order-1',
          userId: 'test-user',
          items: const [],
          createdAt: DateTime.utc(2026, 10, 1),
          status: 'ready',
          shopName: 'Actual Shop Hub',
        ),
      ]),
    );
    expect(find.text('Actual Shop Hub'), findsOneWidget);
    expect(find.text('ACTIVE PICKUP LOCATION'), findsOneWidget);
    expect(find.text('From your current order'), findsOneWidget);
  });

  testWidgets('push preference persists by field path and survives reopening', (
    tester,
  ) async {
    final store = _SettingsStore();
    final result = await _mount(tester, store);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isTrue,
    );
    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();
    expect(store.writes, [
      {'preferences.pushNotifications': false},
    ]);
    expect(
      (store.document!['preferences'] as Map)['readyForPickupSms'],
      isTrue,
    );
    expect(
      (store.document!['preferences'] as Map)['paperlessInvoices'],
      isFalse,
    );
    expect((store.document!['preferences'] as Map)['quietHours'], isTrue);
    for (final key in [
      'uid',
      'role',
      'approvalStatus',
      'accountStatus',
      'createdAt',
      'fullName',
      'email',
      'phone',
    ]) {
      expect(store.document!.containsKey(key), isTrue);
    }
    result.router.goNamed('profile');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
  });

  testWidgets(
    'rapid push taps make one write and save failure restores value',
    (tester) async {
      final store = _SettingsStore()..gate = Completer<void>();
      await _mount(tester, store);
      await tester.tap(find.byType(SwitchListTile));
      await tester.pump();
      expect(store.writes, hasLength(1));
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
        isNull,
      );
      store.gate!.complete();
      await tester.pumpAndSettle();
      store.failOnce = true;
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        isFalse,
      );
      expect(
        find.text('Could not save notification preference. Please try again.'),
        findsOneWidget,
      );
    },
  );

  testWidgets('missing preference map defaults safely and does not write', (
    tester,
  ) async {
    final store = _SettingsStore();
    store.document!.remove('preferences');
    await _mount(tester, store);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(store.writes, isEmpty);
  });

  testWidgets('password account uses existing Firebase reset pathway', (
    tester,
  ) async {
    final result = await _mount(tester, _SettingsStore());
    await _tapRow(tester, 'Change Password');
    expect(find.text('Reset password?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(result.service.resetEmail, isNull);
    await _tapRow(tester, 'Change Password');
    await tester.tap(find.text('Send Email'));
    await tester.pumpAndSettle();
    expect(result.service.resetEmail, 'customer@example.com');
    expect(
      find.text('Password reset instructions have been sent to your email.'),
      findsOneWidget,
    );
  });

  testWidgets('Google-only account does not request a password reset', (
    tester,
  ) async {
    final result = await _mount(
      tester,
      _SettingsStore(),
      identity: (
        uid: 'test-user',
        email: 'customer@example.com',
        passwordProvider: false,
        googleOnly: true,
      ),
    );
    await _tapRow(tester, 'Change Password');
    expect(
      find.text('Password management is handled by your Google account.'),
      findsOneWidget,
    );
    expect(result.service.resetEmail, isNull);
  });

  testWidgets('language, privacy, support and About behave safely', (
    tester,
  ) async {
    await _mount(tester, _SettingsStore());
    for (final (title, expected) in [
      ('Language', 'English is currently supported.'),
      (
        'Privacy & Security',
        'Your account uses Firebase Authentication. Profile preferences are saved to your account.',
      ),
      ('Help & Support', 'Support contact details are not available yet.'),
    ]) {
      await _tapRow(tester, title);
      expect(find.text(expected), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    }
    await _tapRow(tester, 'About PikZen');
    expect(
      find.text('PikZen helps customers plan grocery pickup.'),
      findsOneWidget,
    );
    expect(find.text('1.0.0'), findsNothing);
  });

  testWidgets(
    'logout cancel stays signed in; confirm clears session and route',
    (tester) async {
      final result = await _mount(tester, _SettingsStore());
      await _tapRow(tester, 'Logout');
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(result.service.signOutCalls, 0);
      expect(result.auth.user, isNotNull);
      await _tapRow(tester, 'Logout');
      await tester.tap(find.widgetWithText(TextButton, 'Logout'));
      await tester.pumpAndSettle();
      expect(result.service.signOutCalls, 1);
      expect(result.auth.user, isNull);
      expect(find.text('Common Login'), findsOneWidget);
      expect(result.router.canPop(), isFalse);
    },
  );

  testWidgets('missing customer profile keeps other Settings sections usable', (
    tester,
  ) async {
    final store = _SettingsStore()..document = null;
    await _mount(tester, store);
    expect(find.text('Your customer profile is unavailable.'), findsOneWidget);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    await _tapRow(tester, 'Language');
    expect(find.text('English is currently supported.'), findsOneWidget);
  });

  testWidgets('profile load failure offers retry without blocking other rows', (
    tester,
  ) async {
    final store = _SettingsStore();
    var attempts = 0;
    await _mount(
      tester,
      store,
      loader: (_) async {
        attempts++;
        if (attempts == 1) throw StateError('Offline');
        return store.document;
      },
    );
    expect(
      find.text('Profile preferences could not be loaded.'),
      findsOneWidget,
    );
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    await _tapRow(tester, 'Language');
    await tester.tap(find.text('Close'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Retry'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(attempts, 2);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNotNull,
    );
  });

  testWidgets(
    'password reset failure stays on Settings with friendly feedback',
    (tester) async {
      final result = await _mount(tester, _SettingsStore());
      result.service.failReset = true;
      await _tapRow(tester, 'Change Password');
      await tester.tap(find.text('Send Email'));
      await tester.pumpAndSettle();
      expect(
        find.text('Could not send reset instructions. Please try again.'),
        findsOneWidget,
      );
      expect(result.service.resetEmail, isNull);
      expect(find.byType(SettingsScreen), findsOneWidget);
    },
  );

  testWidgets('logout failure leaves the signed-in Settings session intact', (
    tester,
  ) async {
    final result = await _mount(tester, _SettingsStore());
    result.service.failSignOut = true;
    await _tapRow(tester, 'Logout');
    await tester.tap(find.widgetWithText(TextButton, 'Logout'));
    await tester.pumpAndSettle();
    expect(result.auth.user, isNotNull);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(find.text('Could not log out. Please try again.'), findsOneWidget);
  });

  testWidgets('small phone keeps bottom action reachable without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await _mount(tester, _SettingsStore());
    final logout = find.widgetWithText(ListTile, 'Logout');
    await tester.ensureVisible(logout);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(logout, findsOneWidget);
  });
}
