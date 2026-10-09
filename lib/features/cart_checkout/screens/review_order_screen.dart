import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/cart_item_model.dart';
import '../../../models/payment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../providers/checkout_provider.dart';
import '../widgets/checkout_ui.dart';

class ReviewOrderScreen extends StatefulWidget {
  const ReviewOrderScreen({super.key});

  @override
  State<ReviewOrderScreen> createState() => _ReviewOrderScreenState();
}

class _ReviewOrderScreenState extends State<ReviewOrderScreen> {
  bool _checking = false;

  Future<void> _confirm() async {
    if (_checking) return;
    final cart = context.read<CartProvider>();
    final checkout = context.read<CheckoutProvider>();
    final connected = Firebase.apps.isNotEmpty;
    final uid = connected
        ? FirebaseAuth.instance.currentUser?.uid
        : context.read<AuthProvider>().user?.id;
    String? error;
    if (cart.items.isEmpty) {
      error = 'Add items to your cart before continuing.';
    } else if (checkout.pickupDate == null ||
        checkout.pickupTime == null ||
        !PickupAvailability.slotsFor(
          checkout.pickupDate!,
          DateTime.now(),
        ).contains(checkout.pickupTime)) {
      error = 'Select an available pickup date and time.';
    } else if (uid == null) {
      error = 'Sign in before placing your order.';
    }
    if (error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(error)));
      if (uid == null && connected) context.goNamed('login');
      return;
    }
    setState(() => _checking = true);
    try {
      if (connected) {
        final before = {
          for (final item in cart.items)
            item.product.id: (
              item.quantity,
              item.product.priceMinor,
              item.product.stockQuantity,
              item.product.shopId,
            ),
        };
        final latest = await FirestoreService().currentProducts();
        if (!mounted) return;
        cart.syncProducts(latest);
        if (cart.items.length != before.length ||
            cart.items.any(
              (item) =>
                  before[item.product.id] !=
                  (
                    item.quantity,
                    item.product.priceMinor,
                    item.product.stockQuantity,
                    item.product.shopId,
                  ),
            )) {
          throw const OrderActionException(
            'Product stock or prices changed. Review your cart before placing the order.',
          );
        }
      }
      final items = cart.items;
      final shopId = items.first.product.shopId;
      if (items.any((item) => item.product.shopId != shopId)) {
        throw const OrderActionException(
          'Place items from one store at a time.',
        );
      }
      if (connected && shopId.isEmpty) {
        throw const OrderActionException(
          'A pickup shop is unavailable for this item.',
        );
      }
      final draft = OrderService().newDraft(
        customerId: uid!,
        items: items,
        pickupAt: checkout.pickupTime,
        replacementPreference: checkout.preference.name,
        shopId: shopId.isNotEmpty ? shopId : null,
        shopName: items.first.product.shopName.isEmpty
            ? null
            : items.first.product.shopName,
      );
      checkout.markReviewed();
      final data = PaymentCheckoutData(orderDraft: draft);
      switch (checkout.paymentMethod) {
        case PaymentMethod.card:
          context.pushNamed(
            'card-payment',
            extra: data.toExtra(PaymentMethod.card),
          );
        case PaymentMethod.cashOnPickup:
        case PaymentMethod.ewallet:
        case PaymentMethod.onlineBanking:
          context.pushNamed(
            checkout.paymentMethod.routeName,
            extra: data.toExtra(checkout.paymentMethod),
          );
      }
    } on OrderActionException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(error.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to refresh products. Please try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final checkout = context.watch<CheckoutProvider>();
    final date = checkout.pickupDate;
    final time = checkout.pickupTime;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: CheckoutHeader(
        title: 'Review Order',
        onBack: () => context.canPop()
            ? context.pop()
            : context.goNamed(
                'replacement-preference',
                queryParameters: const {'returnToReview': 'true'},
              ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                children: [
                  const Text(
                    'Review Your Order',
                    style: TextStyle(
                      fontFamily: 'serif',
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Please double-check your pickup details and items before confirming.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _section(
                    child: Row(
                      children: [
                        _icon(
                          Icons.schedule_outlined,
                          AppColors.primary,
                          AppColors.softGreen,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Scheduled Pickup Time',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                date == null
                                    ? 'Select pickup date'
                                    : fullDate(date),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              Text(
                                time == null
                                    ? 'Select pickup time'
                                    : '${pickupTimeLabel(time)} - ${pickupTimeLabel(time.add(const Duration(minutes: 30)))}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                              Text(
                                cart.items.isEmpty ||
                                        cart
                                            .items
                                            .first
                                            .product
                                            .shopName
                                            .isEmpty
                                    ? 'Pickup shop unavailable'
                                    : cart.items.first.product.shopName,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.secondaryText,
                                ),
                              ),
                            ],
                          ),
                        ),
                        _link('Change', () => context.pushNamed('pickup-date')),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    child: Column(
                      children: [
                        _heading(
                          Icons.swap_horiz,
                          'Item Replacements',
                          'Edit',
                          () => context.pushNamed(
                            'replacement-preference',
                            queryParameters: const {'returnToReview': 'true'},
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.all(11),
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.check_circle,
                                color: AppColors.primary,
                                size: 24,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _preferenceLabel(checkout.preference),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                    Text(
                                      _preferenceDescription(
                                        checkout.preference,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        color: AppColors.secondaryText,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    child: Column(
                      children: [
                        _heading(
                          Icons.shopping_bag_outlined,
                          'Item Breakdown (${cart.count} items)',
                          'View All',
                          () => context.goNamed('cart'),
                        ),
                        const SizedBox(height: 8),
                        if (cart.items.isEmpty)
                          const Padding(
                            padding: EdgeInsets.all(12),
                            child: Text('Your cart is empty.'),
                          ),
                        for (final item in cart.items) _itemRow(item),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    borderRadius: BorderRadius.circular(13),
                    onTap: () => context.pushNamed('payment-method'),
                    child: _section(
                      child: Column(
                        children: [
                          _heading(
                            Icons.credit_card,
                            'Payment Method',
                            'Change',
                            () => context.pushNamed('payment-method'),
                          ),
                          const SizedBox(height: 9),
                          Row(
                            children: [
                              _icon(
                                checkout.paymentMethod == PaymentMethod.card
                                    ? Icons.credit_card
                                    : Icons.payments_outlined,
                                AppColors.primaryText,
                                const Color(0xFFEBEFF0),
                              ),
                              const SizedBox(width: 9),
                              Expanded(
                                child: Text(
                                  checkout.paymentMethod.label,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                              const Text(
                                'Details',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _section(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Order Summary',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _priceRow('Subtotal', rupees(cart.totalMinor)),
                        const SizedBox(height: 7),
                        _priceRow(
                          'Service Fee',
                          rupees(checkout.serviceFeeMinor),
                        ),
                        const Divider(height: 20),
                        _priceRow(
                          checkout.paymentMethod == PaymentMethod.cashOnPickup
                              ? 'Total Due'
                              : 'Total',
                          rupees(checkout.totalMinor(cart.totalMinor)),
                          total: true,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 18),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: FilledButton.icon(
                  onPressed: _checking ? null : _confirm,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text(
                    _checking ? 'Checking order...' : 'Confirm & Place Order',
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF075F1A),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _section({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F6F3),
      borderRadius: BorderRadius.circular(13),
    ),
    child: child,
  );
  static Widget _icon(IconData icon, Color color, Color background) =>
      Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: color, size: 19),
      );
  static Widget _link(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    style: TextButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      minimumSize: const Size(0, 30),
    ),
    child: Text(
      label,
      style: const TextStyle(fontSize: 11, color: AppColors.primary),
    ),
  );
  static Widget _heading(
    IconData icon,
    String title,
    String action,
    VoidCallback onTap,
  ) => Row(
    children: [
      Icon(icon, size: 18, color: AppColors.primary),
      const SizedBox(width: 6),
      Expanded(
        child: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
        ),
      ),
      _link(action, onTap),
    ],
  );
  static Widget _itemRow(CartItemModel item) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      children: [
        _icon(Icons.eco_outlined, AppColors.primary, AppColors.softGreen),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Qty: ${item.quantity} • ${item.unit ?? (item.product.unit.isNotEmpty ? item.product.unit : '${rupees(item.product.priceMinor)} each')}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Text(
          rupees(item.quantity * item.product.priceMinor),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
  static Widget _priceRow(String label, String price, {bool total = false}) =>
      Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: total ? FontWeight.bold : null,
              ),
            ),
          ),
          Text(
            price,
            style: TextStyle(
              fontSize: total ? 13 : 11,
              color: total ? AppColors.primary : AppColors.primaryText,
              fontWeight: total ? FontWeight.bold : null,
            ),
          ),
        ],
      );
  static String _preferenceLabel(ReplacementPreference value) =>
      switch (value) {
        ReplacementPreference.allowReplacement => 'Allow shopper replacements',
        ReplacementPreference.contactMe => 'Contact me',
        ReplacementPreference.noReplacement => 'No replacements',
      };
  static String _preferenceDescription(ReplacementPreference value) =>
      switch (value) {
        ReplacementPreference.allowReplacement =>
          "We'll text you if an item is out of stock",
        ReplacementPreference.contactMe => 'Ask before choosing an alternative',
        ReplacementPreference.noReplacement => 'Skip unavailable items',
      };
}
