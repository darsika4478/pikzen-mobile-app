import 'package:cloud_firestore/cloud_firestore.dart';

import 'cart_item_model.dart';
import 'product_model.dart';

/// Basic order data; lifecycle rules and totals are left to feature work.
class OrderModel {
  OrderModel({
    required this.id,
    required this.userId,
    required List<CartItemModel> items,
    required this.createdAt,
    this.pickupAt,
    this.replacementPreference,
    this.status,
    this.completedAt,
    this.shopId,
    this.shopName,
    this.totalMinor,
    this.currencyCode,
    this.paymentMethod,
    this.paymentStatus,
    this.updatedAt,
    this.acceptedAt,
    this.preparingAt,
    this.readyAt,
    this.collectedAt,
    this.cancelledAt,
    this.cancellationReason,
    this.cancellationNote,
  }) : items = List<CartItemModel>.unmodifiable(items);

  final String id;
  final String userId;

  /// Immutable item snapshots captured when the order is created.
  final List<CartItemModel> items;
  final DateTime createdAt;
  final DateTime? pickupAt;
  final String? replacementPreference;

  /// Optional lifecycle fields when provided by the shared order source.
  final String? status;
  final DateTime? completedAt;
  final String? shopId;
  final String? shopName;
  final int? totalMinor;
  final String? currencyCode;
  final String? paymentMethod;
  final String? paymentStatus;
  final DateTime? updatedAt;
  final DateTime? acceptedAt;
  final DateTime? preparingAt;
  final DateTime? readyAt;
  final DateTime? collectedAt;
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final String? cancellationNote;

  int get calculatedTotalMinor => items.fold<int>(
    0,
    (total, item) => total + item.product.priceMinor * item.quantity,
  );

  int get effectiveTotalMinor => totalMinor ?? calculatedTotalMinor;
  String get effectiveCurrencyCode =>
      currencyCode ??
      (items.isEmpty ? 'LKR' : items.first.product.currencyCode);

  OrderModel copyWith({
    String? status,
    String? paymentMethod,
    String? paymentStatus,
    DateTime? updatedAt,
  }) => OrderModel(
    id: id,
    userId: userId,
    items: items,
    createdAt: createdAt,
    pickupAt: pickupAt,
    replacementPreference: replacementPreference,
    status: status ?? this.status,
    completedAt: completedAt,
    shopId: shopId,
    shopName: shopName,
    totalMinor: totalMinor,
    currencyCode: currencyCode,
    paymentMethod: paymentMethod ?? this.paymentMethod,
    paymentStatus: paymentStatus ?? this.paymentStatus,
    updatedAt: updatedAt ?? this.updatedAt,
    acceptedAt: acceptedAt,
    preparingAt: preparingAt,
    readyAt: readyAt,
    collectedAt: collectedAt,
    cancelledAt: cancelledAt,
    cancellationReason: cancellationReason,
    cancellationNote: cancellationNote,
  );

  Map<String, dynamic> toFirestore({bool serverTimestamps = false}) => {
    'id': id,
    'customerId': userId,
    'shopId': shopId,
    'shopName': shopName,
    'items': items
        .map(
          (item) => {
            'productId': item.product.id,
            'productName': item.product.name,
            'quantity': item.quantity,
            'unitPriceMinor': item.product.priceMinor,
            'currencyCode': item.product.currencyCode,
            'imageUrl': item.product.imageUrl,
            'unit': item.unit,
          },
        )
        .toList(),
    'totalMinor': effectiveTotalMinor,
    'currencyCode': effectiveCurrencyCode,
    'paymentMethod': paymentMethod,
    'paymentStatus': paymentStatus,
    'status': status,
    'pickupAt': pickupAt,
    'replacementPreference': replacementPreference,
    'createdAt': serverTimestamps
        ? FieldValue.serverTimestamp()
        : Timestamp.fromDate(createdAt),
    'updatedAt': serverTimestamps
        ? FieldValue.serverTimestamp()
        : updatedAt == null
        ? Timestamp.fromDate(createdAt)
        : Timestamp.fromDate(updatedAt!),
    'acceptedAt': acceptedAt == null ? null : Timestamp.fromDate(acceptedAt!),
    'preparingAt': preparingAt == null
        ? null
        : Timestamp.fromDate(preparingAt!),
    'readyAt': readyAt == null ? null : Timestamp.fromDate(readyAt!),
    'collectedAt': collectedAt == null
        ? null
        : Timestamp.fromDate(collectedAt!),
    'cancelledAt': cancelledAt == null
        ? null
        : Timestamp.fromDate(cancelledAt!),
    if (cancellationReason != null) 'cancellationReason': cancellationReason,
    if (cancellationNote != null) 'cancellationNote': cancellationNote,
    'completedAt': completedAt == null
        ? null
        : Timestamp.fromDate(completedAt!),
  };

  factory OrderModel.fromFirestore(String id, Map<String, dynamic> data) {
    final rawItems = data['items'];
    final items = rawItems is Iterable
        ? rawItems.whereType<Map>().map((raw) {
            final item = Map<String, dynamic>.from(raw);
            final productId = (item['productId'] ?? item['id'] ?? '')
                .toString();
            final productName =
                (item['productName'] ?? item['name'] ?? 'Product').toString();
            final price = _intValue(
              item['unitPriceMinor'] ?? item['priceMinor'],
            );
            final currency =
                (item['currencyCode'] ?? data['currencyCode'] ?? 'LKR')
                    .toString();
            return CartItemModel(
              product: ProductModel(
                id: productId,
                name: productName,
                priceMinor: price,
                currencyCode: currency,
                imageUrl: item['imageUrl'] as String?,
              ),
              quantity: _intValue(item['quantity'], fallback: 1),
              unit: item['unit'] as String?,
            );
          }).toList()
        : <CartItemModel>[];
    final createdAt = _dateValue(data['createdAt']);
    if (createdAt == null) {
      throw const FormatException('Order is missing createdAt.');
    }

    return OrderModel(
      id: (data['id'] ?? id).toString(),
      userId: (data['customerId'] ?? data['userId'] ?? '').toString(),
      items: items,
      createdAt: createdAt,
      pickupAt: _dateValue(data['pickupAt']),
      replacementPreference: data['replacementPreference'] as String?,
      status: data['status'] as String?,
      completedAt: _dateValue(data['completedAt']),
      shopId: data['shopId'] as String?,
      shopName: data['shopName'] as String?,
      totalMinor: data['totalMinor'] == null
          ? null
          : _intValue(data['totalMinor']),
      currencyCode: data['currencyCode'] as String?,
      paymentMethod: data['paymentMethod'] as String?,
      paymentStatus: data['paymentStatus'] as String?,
      updatedAt: _dateValue(data['updatedAt']),
      acceptedAt: _dateValue(data['acceptedAt']),
      preparingAt: _dateValue(data['preparingAt']),
      readyAt: _dateValue(data['readyAt']),
      collectedAt: _dateValue(data['collectedAt']),
      cancelledAt: _dateValue(data['cancelledAt']),
      cancellationReason: data['cancellationReason'] as String?,
      cancellationNote: data['cancellationNote'] as String?,
    );
  }
}

DateTime? _dateValue(Object? value) => switch (value) {
  Timestamp timestamp => timestamp.toDate(),
  DateTime dateTime => dateTime,
  _ => null,
};

int _intValue(Object? value, {int fallback = 0}) => switch (value) {
  int integer => integer,
  num number => number.round(),
  String text => int.tryParse(text) ?? fallback,
  _ => fallback,
};
