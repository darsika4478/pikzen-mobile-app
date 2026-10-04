import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/models/order_model.dart';
import 'package:pikzen/models/payment_model.dart';

void main() {
  final draft = OrderModel(
    id: 'stable-order-id',
    userId: 'customer-1',
    items: const [],
    createdAt: DateTime.utc(2026, 10, 1),
    totalMinor: 234567,
    currencyCode: 'LKR',
  );

  test('legacy wallet identifier resolves to canonical demo metadata', () {
    expect(PaymentMethod.fromValue('eWallet'), PaymentMethod.ewallet);
    expect(PaymentMethod.fromValue('ewallet').identifier, 'ewallet');
    expect(PaymentMethod.fromValue(null), PaymentMethod.card);
  });

  test('legacy cash draft and typed checkout arguments remain compatible', () {
    final checkout = PaymentCheckoutData.fromExtra(draft);
    expect(checkout.orderDraft, same(draft));
    expect(PaymentCheckoutData.fromExtra(checkout), same(checkout));
    expect(checkout.id, draft.id);
    expect(checkout.amountLabel, 'LKR 2,345.67');
  });

  test('draft total, currency and ID override stale navigation values', () {
    final checkout = PaymentCheckoutData.fromExtra({
      'amountMinor': 1,
      'currencyCode': 'USD',
      'orderId': 'stale-id',
      'orderDraft': draft,
    });
    expect(checkout.totalMinor, 234567);
    expect(checkout.currency, 'LKR');
    expect(checkout.id, 'stable-order-id');
  });

  test('navigation ignores sensitive fields and forwards safe keys only', () {
    final checkout = PaymentCheckoutData.fromExtra({
      'amountMinor': 12345,
      'currencyCode': 'LKR',
      'cardNumber': '1111222233334444',
      'cardHolder': 'Test User',
      'expiry': '12/30',
      'cvv': '123',
      'password': 'dummy',
      'otp': '123456',
    });
    expect(
      checkout.toExtra(PaymentMethod.card).keys,
      unorderedEquals([
        'amountMinor',
        'currencyCode',
        'orderId',
        'orderDraft',
        'selectedMethod',
        'paymentMethod',
      ]),
    );
    expect(
      checkout.successExtra(PaymentMethod.card, null).keys,
      unorderedEquals([
        'order',
        'orderId',
        'amountMinor',
        'currencyCode',
        'paymentMethod',
        'paymentStatus',
        'isDemo',
      ]),
    );
  });

  test('missing values stay missing and supplied zero stays zero', () {
    final missing = PaymentCheckoutData.fromExtra(null);
    expect(missing.totalMinor, isNull);
    expect(missing.id, isNull);
    expect(missing.amountLabel, 'Not available from checkout');
    expect(formatPaymentAmount(0, 'LKR'), 'LKR 0.00');
    expect(formatPaymentAmount(123456, 'USD'), 'USD 1,234.56');
  });

  for (final method in PaymentMethod.values) {
    test(
      '${method.identifier} order snapshot contains safe payment metadata',
      () {
        final saved = draft.copyWith(
          paymentMethod: method.identifier,
          paymentStatus: method.paymentStatus,
        );
        final encoded = saved.toFirestore();
        expect(encoded['paymentMethod'], method.identifier);
        expect(
          encoded['paymentStatus'],
          method == PaymentMethod.cashOnPickup ? 'unpaid' : 'demo',
        );
        for (final key in [
          'cardNumber',
          'cardHolder',
          'expiry',
          'cvv',
          'password',
          'otp',
          'pin',
        ]) {
          expect(encoded.containsKey(key), isFalse);
        }
        final decoded = OrderModel.fromFirestore(saved.id, encoded);
        expect(decoded.paymentMethod, method.identifier);
        expect(decoded.paymentStatus, method.paymentStatus);
        final result = const PaymentCheckoutData().successExtra(
          method,
          decoded,
        );
        expect(result['amountMinor'], 234567);
        expect(result['orderId'], 'stable-order-id');
        expect(result['currencyCode'], 'LKR');
      },
    );
  }
}
