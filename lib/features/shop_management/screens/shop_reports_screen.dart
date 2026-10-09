import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/services/order_service.dart';
import '../../../models/order_model.dart';
import '../../../models/payment_model.dart';
import '../models/shop_insights.dart';
import '../widgets/dashboard_surface.dart';

/// Sales & performance for the signed-in shop, computed from its orders.
class ShopReportsScreen extends StatefulWidget {
  const ShopReportsScreen({super.key, this.orders, this.now});
  final OrderService? orders;

  /// Test seam; defaults to the current time.
  final DateTime? now;

  @override
  State<ShopReportsScreen> createState() => _ShopReportsScreenState();
}

class _ShopReportsScreenState extends State<ShopReportsScreen> {
  late final Stream<List<OrderModel>> _stream =
      (widget.orders ?? OrderService()).forShop();
  int _days = 7;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        tooltip: 'Back',
        onPressed: () => context.canPop()
            ? context.pop()
            : context.goNamed('shop-dashboard'),
        icon: const Icon(Icons.arrow_back),
      ),
      title: const Text('Sales & Performance'),
    ),
    body: SafeArea(
      top: false,
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: StreamBuilder<List<OrderModel>>(
            stream: _stream,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Reports are unavailable right now.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final report = ShopReport.from(
                snapshot.data!,
                now: widget.now ?? DateTime.now(),
                days: _days,
              );
              return ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                children: [
                  _RangePicker(
                    days: _days,
                    onChanged: (days) => setState(() => _days = days),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    reportPeriodLabel(widget.now ?? DateTime.now(), _days),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _KpiGrid(report),
                  const SizedBox(height: 14),
                  _DailySalesChart(report),
                  const SizedBox(height: 14),
                  _StatusBreakdown(report),
                  const SizedBox(height: 14),
                  _TopProducts(report),
                  const SizedBox(height: 14),
                  _PaymentMix(report),
                ],
              );
            },
          ),
        ),
      ),
    ),
  );
}

/// Aggregates for one reporting period. Cancelled orders never count as
/// sales; they are only shown in the status breakdown.
class ShopReport {
  ShopReport._({
    required this.days,
    required this.orders,
    required this.salesMinor,
    required this.completed,
    required this.daily,
    required this.statusCounts,
    required this.topProducts,
    required this.paymentCounts,
  });

  factory ShopReport.from(
    List<OrderModel> all, {
    required DateTime now,
    required int days,
  }) {
    final today = DateTime(now.year, now.month, now.day);
    final start = today.subtract(Duration(days: days - 1));
    final inRange = all.where((o) => !o.createdAt.isBefore(start)).toList();
    final sold = inRange.where((o) => o.status != 'cancelled').toList();
    final chartDays = days == 1 ? 7 : days.clamp(7, 30);
    final chartStart = today.subtract(Duration(days: chartDays - 1));
    final daily = List<int>.filled(chartDays, 0);
    for (final order in all) {
      if (order.status == 'cancelled' || order.createdAt.isBefore(chartStart)) {
        continue;
      }
      final day = DateTime(
        order.createdAt.year,
        order.createdAt.month,
        order.createdAt.day,
      ).difference(chartStart).inDays;
      if (day >= 0 && day < chartDays) daily[day] += order.effectiveTotalMinor;
    }
    final products = <String, ({String name, int quantity, int minor})>{};
    for (final order in sold) {
      for (final item in order.items) {
        final current = products[item.product.id];
        products[item.product.id] = (
          name: item.product.name,
          quantity: (current?.quantity ?? 0) + item.quantity,
          minor:
              (current?.minor ?? 0) + item.quantity * item.product.priceMinor,
        );
      }
    }
    final top = products.values.toList()
      ..sort((a, b) => b.minor.compareTo(a.minor));
    final statuses = <String, int>{};
    for (final order in inRange) {
      final status = order.status ?? 'placed';
      statuses[status] = (statuses[status] ?? 0) + 1;
    }
    final payments = <String, int>{};
    for (final order in sold) {
      final method = order.paymentMethod ?? 'card';
      payments[method] = (payments[method] ?? 0) + 1;
    }
    return ShopReport._(
      days: days,
      orders: sold.length,
      salesMinor: sold.fold(0, (sum, o) => sum + o.effectiveTotalMinor),
      completed: sold
          .where((o) => o.status == 'collected' || o.status == 'completed')
          .length,
      daily: daily,
      statusCounts: statuses,
      topProducts: top.take(5).toList(),
      paymentCounts: payments,
    );
  }

  final int days;
  final int orders;
  final int salesMinor;
  final int completed;

  /// Sales per day for the chart, oldest first, ending today.
  final List<int> daily;
  final Map<String, int> statusCounts;
  final List<({String name, int quantity, int minor})> topProducts;
  final Map<String, int> paymentCounts;

  int get averageMinor => orders == 0 ? 0 : salesMinor ~/ orders;
}

String _money(int minor) => formatPaymentAmount(minor, 'LKR');

class _RangePicker extends StatelessWidget {
  const _RangePicker({required this.days, required this.onChanged});
  final int days;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => SegmentedButton<int>(
    segments: const [
      ButtonSegment(value: 1, label: Text('Today')),
      ButtonSegment(value: 7, label: Text('7 Days')),
      ButtonSegment(value: 30, label: Text('30 Days')),
    ],
    selected: {days},
    showSelectedIcon: false,
    onSelectionChanged: (value) => onChanged(value.first),
    style: SegmentedButton.styleFrom(
      selectedBackgroundColor: AppColors.softGreen,
      selectedForegroundColor: AppColors.primary,
    ),
  );
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid(this.report);
  final ShopReport report;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (Icons.payments_outlined, 'Sales', _money(report.salesMinor)),
      (Icons.receipt_long_outlined, 'Orders', '${report.orders}'),
      (Icons.trending_up_rounded, 'Avg. Order', _money(report.averageMinor)),
      (Icons.task_alt_rounded, 'Completed', '${report.completed}'),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final (icon, label, value) in tiles)
              SizedBox(
                width: width,
                child: DashboardSurface(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: AppColors.primary, size: 20),
                      const SizedBox(height: 10),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primaryText,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => DashboardSurface(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: .5,
            fontWeight: FontWeight.w700,
            color: AppColors.secondaryText,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    ),
  );
}

class _DailySalesChart extends StatelessWidget {
  const _DailySalesChart(this.report);
  final ShopReport report;

  @override
  Widget build(BuildContext context) {
    final peak = report.daily.fold(0, (max, v) => v > max ? v : max);
    final count = report.daily.length;
    final today = DateTime.now();
    return _SectionCard(
      title: 'Daily sales • last $count days',
      child: Semantics(
        label: 'Daily sales chart. Highest day ${_money(peak)}.',
        child: SizedBox(
          height: 150,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < count; i++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: count > 10 ? 1 : 4,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FractionallySizedBox(
                            heightFactor: peak == 0
                                ? .02
                                : (report.daily[i] / peak).clamp(.02, 1.0),
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == count - 1
                                    ? AppColors.primary
                                    : AppColors.primaryLight.withValues(
                                        alpha: .55,
                                      ),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        if (count <= 7) ...[
                          const SizedBox(height: 6),
                          Text(
                            const ['M', 'T', 'W', 'T', 'F', 'S', 'S'][today
                                    .subtract(Duration(days: count - 1 - i))
                                    .weekday -
                                1],
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBreakdown extends StatelessWidget {
  const _StatusBreakdown(this.report);
  final ShopReport report;

  static const _labels = {
    'placed': 'New',
    'accepted': 'Accepted',
    'preparing': 'Preparing',
    'ready': 'Ready',
    'collected': 'Collected',
    'cancelled': 'Cancelled',
  };

  @override
  Widget build(BuildContext context) {
    final total = report.statusCounts.values.fold(0, (a, b) => a + b);
    return _SectionCard(
      title: 'Orders by status',
      child: total == 0
          ? const Text(
              'No orders in this period yet.',
              style: TextStyle(color: AppColors.secondaryText),
            )
          : Column(
              children: [
                for (final entry in _labels.entries)
                  if ((report.statusCounts[entry.key] ?? 0) > 0)
                    _BarRow(
                      label: entry.value,
                      value: report.statusCounts[entry.key]!,
                      total: total,
                      color: entry.key == 'cancelled'
                          ? AppColors.rejectRed
                          : AppColors.primary,
                    ),
              ],
            ),
    );
  }
}

class _BarRow extends StatelessWidget {
  const _BarRow({
    required this.label,
    required this.value,
    required this.total,
    required this.color,
    this.trailing,
  });
  final String label;
  final int value;
  final int total;
  final Color color;
  final String? trailing;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            Text(
              trailing ?? '$value',
              style: const TextStyle(color: AppColors.secondaryText),
            ),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : value / total,
            minHeight: 7,
            color: color,
            backgroundColor: AppColors.border,
          ),
        ),
      ],
    ),
  );
}

class _TopProducts extends StatelessWidget {
  const _TopProducts(this.report);
  final ShopReport report;

  @override
  Widget build(BuildContext context) {
    final best = report.topProducts.isEmpty
        ? 0
        : report.topProducts.first.minor;
    return _SectionCard(
      title: 'Top products',
      child: report.topProducts.isEmpty
          ? const Text(
              'Sales will appear here once customers order.',
              style: TextStyle(color: AppColors.secondaryText),
            )
          : Column(
              children: [
                for (final product in report.topProducts)
                  _BarRow(
                    label: '${product.name} × ${product.quantity}',
                    value: product.minor,
                    total: best,
                    color: AppColors.accent,
                    trailing: _money(product.minor),
                  ),
              ],
            ),
    );
  }
}

class _PaymentMix extends StatelessWidget {
  const _PaymentMix(this.report);
  final ShopReport report;

  @override
  Widget build(BuildContext context) {
    final total = report.paymentCounts.values.fold(0, (a, b) => a + b);
    return _SectionCard(
      title: 'Payment methods',
      child: total == 0
          ? const Text(
              'No paid orders in this period yet.',
              style: TextStyle(color: AppColors.secondaryText),
            )
          : Column(
              children: [
                for (final method in PaymentMethod.values)
                  if ((report.paymentCounts[method.identifier] ?? 0) > 0)
                    _BarRow(
                      label: method.label,
                      value: report.paymentCounts[method.identifier]!,
                      total: total,
                      color: AppColors.info,
                    ),
              ],
            ),
    );
  }
}

/// "Fri, 2 Oct 2026 – Thu, 8 Oct 2026", or just today's date.
String reportPeriodLabel(DateTime now, int days) => days == 1
    ? formatShopDay(now)
    : '${formatShopDay(now.subtract(Duration(days: days - 1)))} – ${formatShopDay(now)}';
