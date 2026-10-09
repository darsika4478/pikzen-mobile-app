import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../models/mock_inventory_item.dart';
import 'product_list_card.dart';
import 'shop_product_thumb.dart';

class InventoryProductCard extends StatelessWidget {
  const InventoryProductCard({
    super.key,
    required this.item,
    required this.onAdjust,
    required this.onMenu,
    required this.selectionMode,
    required this.selected,
    required this.onSelected,
  });
  final MockInventoryItem item;
  final ValueChanged<int> onAdjust;
  final ValueChanged<String> onMenu;
  final bool selectionMode, selected;
  final ValueChanged<bool> onSelected;

  @override
  Widget build(BuildContext context) {
    final warning = item.isLow;
    final empty = item.quantity == 0;
    final color = empty
        ? AppColors.rejectRed
        : warning
        ? AppColors.warning
        : AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(
          color: empty
              ? AppColors.rejectBorder
              : warning
              ? AppColors.orangeBorder
              : AppColors.border,
        ),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(11, 9, 8, 8),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (selectionMode)
                SizedBox(
                  width: 26,
                  height: 48,
                  child: Checkbox(
                    value: selected,
                    onChanged: (v) => onSelected(v ?? false),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ShopProductThumb(product: item.product, size: 48),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 5,
                      runSpacing: 2,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          item.product.name,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (warning)
                          _badge('Low Stock', color, AppColors.lightOrange),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${item.product.price} / ${item.unit}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: AppColors.secondaryText,
                      ),
                    ),
                    const SizedBox(height: 5),
                    if (warning)
                      Text(
                        '${item.quantity} units left (Alert < ${item.lowStockThreshold})',
                        style: const TextStyle(
                          fontSize: 9,
                          color: AppColors.warning,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 5,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (empty)
                            _badge(
                              'Out of Stock',
                              color,
                              AppColors.rejectBackground,
                            )
                          else
                            const ProductStatusBadge(label: 'In Stock'),
                          Text(
                            '${item.quantity} units left',
                            style: const TextStyle(
                              fontSize: 9,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              SizedBox(
                width: 24,
                height: 28,
                child: PopupMenuButton<String>(
                  tooltip: '${item.product.name} menu',
                  padding: EdgeInsets.zero,
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 19,
                    color: AppColors.secondaryText,
                  ),
                  onSelected: onMenu,
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'edit', child: Text('Edit Product')),
                    PopupMenuItem(value: 'view', child: Text('View Product')),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Divider(height: 9, color: AppColors.border),
          ),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Adjust Quantity',
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.secondaryText,
                  ),
                ),
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.border),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _button(
                      'Decrease ${item.product.name}',
                      Icons.remove_rounded,
                      item.quantity == 0 ? null : () => onAdjust(-1),
                      AppColors.secondaryText,
                    ),
                    SizedBox(
                      width: 34,
                      child: Text(
                        '${item.quantity}',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: warning || empty
                              ? color
                              : AppColors.primaryText,
                        ),
                      ),
                    ),
                    _button(
                      'Increase ${item.product.name}',
                      Icons.add_rounded,
                      () => onAdjust(1),
                      AppColors.primary,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _button(
    String tooltip,
    IconData icon,
    VoidCallback? tap,
    Color color,
  ) => IconButton(
    tooltip: tooltip,
    onPressed: tap,
    icon: Icon(icon, size: 17),
    color: color,
    padding: EdgeInsets.zero,
    constraints: const BoxConstraints.tightFor(width: 30, height: 28),
    style: IconButton.styleFrom(
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
  Widget _badge(String text, Color color, Color background) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(12),
    ),
    child: Text(
      text,
      style: TextStyle(fontSize: 8, color: color, fontWeight: FontWeight.w600),
    ),
  );
}
