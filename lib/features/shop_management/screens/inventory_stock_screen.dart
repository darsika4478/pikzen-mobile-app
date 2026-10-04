import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_inventory_item.dart';
import '../widgets/dashboard_bottom_nav.dart';
import '../widgets/inventory_product_card.dart';

class InventoryStockScreen extends StatefulWidget {
  const InventoryStockScreen({super.key});
  @override
  State<InventoryStockScreen> createState() => _InventoryStockScreenState();
}

class _InventoryStockScreenState extends State<InventoryStockScreen> {
  final _items = createMockInventory();
  final _selected = <MockInventoryItem>{};
  String _search = '';
  int _filter = 0;
  bool _batch = false;
  void _back() {
    FocusScope.of(context).unfocus();
    if (context.canPop()) {
      context.pop();
    } else {
      context.goNamed('product-management');
    }
  }

  void _filters() {
    FocusScope.of(context).unfocus();
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                'Filter inventory',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            for (var i = 0; i < 3; i++)
              ListTile(
                title: Text(['All Items', 'Low Stock', 'Out of Stock'][i]),
                trailing: _filter == i
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _filter = i);
                  Navigator.pop(sheetContext);
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _items
        .where(
          (item) =>
              item.product.name.toLowerCase().contains(
                _search.trim().toLowerCase(),
              ) &&
              (_filter == 0 ||
                  (_filter == 1 ? item.isLow : item.quantity == 0)),
        )
        .toList();
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              children: [
                SizedBox(
                  height: 58,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: _back,
                        tooltip: 'Back',
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      const Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.circle,
                                size: 6,
                                color: AppColors.primary,
                              ),
                              SizedBox(width: 7),
                              Text(
                                'Inventory & Stock',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _filters,
                        tooltip: 'Inventory settings',
                        icon: const Icon(Icons.tune_rounded, size: 21),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: SizedBox(
                    height: 42,
                    child: TextField(
                      onChanged: (v) => setState(() => _search = v),
                      style: const TextStyle(fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search inventory...',
                        filled: true,
                        fillColor: AppColors.surface,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 10,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          size: 19,
                          color: AppColors.secondaryText,
                        ),
                        suffixIcon: IconButton(
                          onPressed: _filters,
                          tooltip: 'Filter inventory',
                          icon: const Icon(
                            Icons.filter_alt_rounded,
                            size: 18,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(11),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                  child: Row(
                    children: [
                      for (var i = 0; i < 3; i++) ...[
                        if (i > 0) const SizedBox(width: 6),
                        Expanded(child: _chip(i)),
                      ],
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 3, 9, 0),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'QUICK UPDATE (VARIANT B)',
                          style: TextStyle(
                            fontSize: 10,
                            color: AppColors.secondaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(() {
                          _batch = !_batch;
                          if (!_batch) {
                            _selected.clear();
                          }
                        }),
                        child: Text(
                          _batch ? 'Done' : 'Batch Select',
                          style: const TextStyle(fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? Center(
                          child: Text(
                            _filter == 2 && _search.trim().isEmpty
                                ? 'No out-of-stock products'
                                : 'No inventory items found',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        )
                      : ListView.separated(
                          keyboardDismissBehavior:
                              ScrollViewKeyboardDismissBehavior.onDrag,
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                          itemCount: visible.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(height: 8),
                          itemBuilder: (_, index) {
                            final item = visible[index];
                            return InventoryProductCard(
                              key: ValueKey(item.product.visualType),
                              item: item,
                              selectionMode: _batch,
                              selected: _selected.contains(item),
                              onSelected: (v) => setState(() {
                                if (v) {
                                  _selected.add(item);
                                } else {
                                  _selected.remove(item);
                                }
                              }),
                              onAdjust: (delta) => setState(
                                () => item.quantity = (item.quantity + delta)
                                    .clamp(0, 999999),
                              ),
                              onMenu: (action) {
                                FocusScope.of(context).unfocus();
                                if (action == 'edit') {
                                  context.pushNamed(
                                    'add-edit-product',
                                    queryParameters: {
                                      'product': item.product.visualType.name,
                                    },
                                  );
                                } else {
                                  showDialog<void>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: Text(item.product.name),
                                      content: Text(
                                        '${item.product.price} / ${item.unit}\n${item.status}\n${item.quantity} units left',
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(dialogContext),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  );
                                }
                              },
                            );
                          },
                        ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        FocusScope.of(context).unfocus();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Stock updated successfully'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.check_rounded, size: 19),
                      label: const Text(
                        'Update Stock',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(9),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: DashboardBottomNav(
        selectedIndex: 2,
        onSelected: (index) {
          FocusScope.of(context).unfocus();
          switch (index) {
            case 0:
              context.goNamed('shop-dashboard');
            case 1:
              context.pushNamed('incoming-orders');
            case 2:
              _back();
            case 3:
              context.pushNamed('shop-profile');
          }
        },
      ),
    );
  }

  Widget _chip(int index) {
    final active = _filter == index;
    final color = index == 0
        ? AppColors.primary
        : index == 1
        ? AppColors.warning
        : AppColors.rejectRed;
    return Material(
      color: active
          ? index == 0
                ? AppColors.primary
                : index == 1
                ? AppColors.lightOrange
                : AppColors.rejectBackground
          : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: BorderSide(color: active ? color : AppColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => setState(() => _filter = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 5),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (index > 0) ...[
                Icon(Icons.circle, size: 5, color: color),
                const SizedBox(width: 4),
              ],
              Flexible(
                child: Text(
                  ['All Items', 'Low Stock', 'Out of Stock'][index],
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: active && index == 0
                        ? AppColors.surface
                        : AppColors.primaryText,
                  ),
                ),
              ),
              if (index == 0) ...[
                const SizedBox(width: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 1,
                  ),
                  decoration: BoxDecoration(
                    color: active
                        ? AppColors.primaryLight
                        : AppColors.softGreen,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '24',
                    style: TextStyle(
                      fontSize: 9,
                      color: active ? AppColors.surface : AppColors.primary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
