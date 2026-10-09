import 'package:flutter/foundation.dart';

import '../../../models/payment_model.dart';

/// Checkout choices remain a local draft until the existing order confirmation.
enum ReplacementPreference { allowReplacement, contactMe, noReplacement }

class PickupAvailability {
  static const openingHour = 9;
  static const closingHour = 20;
  static const slotMinutes = 30;
  static const slotStartHour = 9;
  static const slotEndHour = 19;
  static const slotEndMinute = 30;

  /// Shops need time to pick and pack, so the earliest slot starts at least
  /// this long after checkout.
  static const preparationLeadTime = Duration(minutes: 30);

  static List<DateTime> slotsFor(DateTime day, DateTime now) {
    final earliest = now.add(preparationLeadTime);
    final slots = <DateTime>[];
    for (var hour = slotStartHour; hour <= slotEndHour; hour++) {
      for (var minute = 0; minute < 60; minute += slotMinutes) {
        if (hour == slotEndHour && minute > slotEndMinute) break;
        final slot = DateTime(day.year, day.month, day.day, hour, minute);
        if (!slot.isBefore(earliest)) slots.add(slot);
      }
    }
    return slots;
  }
}

class CheckoutProvider extends ChangeNotifier {
  String? _owner;
  ReplacementPreference _preference = ReplacementPreference.allowReplacement;
  DateTime? _pickupDate;
  DateTime? _pickupTime;
  PaymentMethod _paymentMethod = PaymentMethod.card;
  DateTime? _reviewedAt;
  int _paymentAttemptCount = 0;
  String? _paymentAttemptStatus;

  ReplacementPreference get preference => _preference;
  DateTime? get pickupDate => _pickupDate;
  DateTime? get pickupTime => _pickupTime;
  PaymentMethod get paymentMethod => _paymentMethod;
  DateTime? get reviewedAt => _reviewedAt;
  int get paymentAttemptCount => _paymentAttemptCount;
  String? get paymentAttemptStatus => _paymentAttemptStatus;
  int get serviceFeeMinor => 0;
  int totalMinor(int subtotalMinor) => subtotalMinor + serviceFeeMinor;

  void bindUser(String? uid) {
    if (_owner == uid) return;
    _owner = uid;
    _preference = ReplacementPreference.allowReplacement;
    _pickupDate = null;
    _pickupTime = null;
    _paymentMethod = PaymentMethod.card;
    _reviewedAt = null;
    _paymentAttemptCount = 0;
    _paymentAttemptStatus = null;
    notifyListeners();
  }

  void setPreference(ReplacementPreference value) {
    if (_preference == value) return;
    _preference = value;
    _reviewedAt = null;
    notifyListeners();
  }

  void setPaymentMethod(PaymentMethod value) {
    if (_paymentMethod == value) return;
    _paymentMethod = value;
    _reviewedAt = null;
    _paymentAttemptStatus = null;
    notifyListeners();
  }

  void markReviewed() {
    _reviewedAt = DateTime.now();
    notifyListeners();
  }

  void recordPaymentAttempt(String status) {
    _paymentAttemptCount++;
    _paymentAttemptStatus = status;
    notifyListeners();
  }

  void setPickupDate(DateTime date, {DateTime? now}) {
    final localNow = now ?? DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final today = DateTime(localNow.year, localNow.month, localNow.day);
    if (day.isBefore(today) ||
        PickupAvailability.slotsFor(day, localNow).isEmpty) {
      return;
    }
    if (_pickupDate == day) {
      if (_pickupTime != null &&
          !PickupAvailability.slotsFor(day, localNow).contains(_pickupTime)) {
        _pickupTime = null;
        _reviewedAt = null;
        notifyListeners();
      }
      return;
    }
    _pickupDate = day;
    _pickupTime = null;
    _reviewedAt = null;
    notifyListeners();
  }

  void resetPickup() {
    if (_pickupDate == null && _pickupTime == null) return;
    _pickupDate = null;
    _pickupTime = null;
    _reviewedAt = null;
    notifyListeners();
  }

  void setPickupTime(DateTime time, {DateTime? now}) {
    final day = _pickupDate;
    if (day == null ||
        !PickupAvailability.slotsFor(
          day,
          now ?? DateTime.now(),
        ).contains(time)) {
      return;
    }
    if (_pickupTime == time) return;
    _pickupTime = time;
    _reviewedAt = null;
    notifyListeners();
  }
}
