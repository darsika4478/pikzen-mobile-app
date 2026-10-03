import 'package:flutter_test/flutter_test.dart';
import 'package:pikzen/features/cart_checkout/providers/checkout_provider.dart';

void main() {
  test('preference, pickup date and time share one mutable draft', () {
    final draft = CheckoutProvider();
    addTearDown(draft.dispose);
    draft.bindUser('customer-1');
    expect(draft.preference, ReplacementPreference.allowReplacement);
    draft.setPreference(ReplacementPreference.contactMe);
    expect(draft.preference, ReplacementPreference.contactMe);

    final now = DateTime(2026, 9, 13, 8);
    final first = DateTime(2026, 9, 13);
    draft.setPickupDate(first, now: now);
    draft.setPickupTime(DateTime(2026, 9, 13, 10), now: now);
    expect(draft.pickupTime, DateTime(2026, 9, 13, 10));

    draft.setPickupDate(DateTime(2026, 9, 14), now: now);
    expect(draft.pickupTime, isNull);
    draft.resetPickup();
    expect(draft.pickupDate, isNull);
    expect(draft.pickupTime, isNull);
  });

  test('past days and past same-day slots cannot be selected', () {
    final draft = CheckoutProvider();
    addTearDown(draft.dispose);
    final now = DateTime(2026, 9, 13, 11, 15);
    draft.setPickupDate(DateTime(2026, 9, 12), now: now);
    expect(draft.pickupDate, isNull);
    draft.setPickupDate(DateTime(2026, 9, 13), now: now);
    draft.setPickupTime(DateTime(2026, 9, 13, 10), now: now);
    expect(draft.pickupTime, isNull);
    draft.setPickupTime(DateTime(2026, 9, 13, 11, 30), now: now);
    expect(draft.pickupTime, DateTime(2026, 9, 13, 11, 30));
    draft.bindUser('another-customer');
    expect(draft.pickupDate, isNull);
  });
}
