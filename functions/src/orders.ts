import { DocumentReference, FieldValue, Firestore, Timestamp, Transaction } from 'firebase-admin/firestore';
import { HttpsError } from 'firebase-functions/v2/https';

type RecordValue = Record<string, unknown>;
type OrderItem = { productId: string; quantity: number };
type PlaceInput = {
  orderId: string;
  items: OrderItem[];
  pickupAtMillis: number;
  replacementPreference: string;
  paymentMethod: string;
};

const customerCancelStatuses = new Set([
  'placed', 'pending', 'accepted', 'confirmed', 'preparing',
]);
const cancellationReasons = new Set([
  'changedMind', 'wrongPickupTime', 'foundElsewhere', 'other',
]);
const paymentStatuses: Record<string, string> = {
  card: 'demo', ewallet: 'demo', onlineBanking: 'demo', cashOnPickup: 'unpaid',
};
const preferences = new Set(['allowReplacement', 'contactMe', 'noReplacement']);

function fail(reason: string, message: string, code: 'invalid-argument' | 'failed-precondition' | 'permission-denied' | 'not-found' | 'already-exists' = 'invalid-argument'): never {
  throw new HttpsError(code, message, { reason });
}

function object(value: unknown): RecordValue | null {
  return value !== null && typeof value === 'object' && !Array.isArray(value)
    ? value as RecordValue : null;
}

function identifier(value: unknown): value is string {
  return typeof value === 'string' && /^[A-Za-z0-9_-]{1,120}$/.test(value);
}

function parsePlaceInput(raw: unknown): PlaceInput {
  const data = object(raw);
  if (!data || !identifier(data.orderId) || data.orderId.length < 8) {
    return fail('invalid-order-id', 'Start checkout again.');
  }
  if (!Array.isArray(data.items) || data.items.length < 1 || data.items.length > 100) {
    return fail('invalid-items', 'Add valid items before placing an order.');
  }
  const ids = new Set<string>();
  const items: OrderItem[] = data.items.map((value: unknown) => {
    const item = object(value);
    if (!item || !identifier(item.productId) || !Number.isSafeInteger(item.quantity)
      || (item.quantity as number) < 1 || (item.quantity as number) > 1000) {
      return fail('invalid-quantity', 'Review the item quantities in your cart.');
    }
    if (ids.has(item.productId as string)) {
      return fail('duplicate-product', 'An item appears twice in this order.');
    }
    ids.add(item.productId as string);
    return { productId: item.productId as string, quantity: item.quantity as number };
  });
  const pickupAtMillis = data.pickupAtMillis;
  const now = Date.now();
  if (!Number.isSafeInteger(pickupAtMillis) || (pickupAtMillis as number) <= now
    || (pickupAtMillis as number) > now + 31 * 24 * 60 * 60 * 1000) {
    return fail('invalid-pickup-data', 'Select a valid future pickup time.');
  }
  if (!preferences.has(data.replacementPreference as string)) {
    return fail('invalid-replacement-preference', 'Select a replacement preference.');
  }
  if (typeof data.paymentMethod !== 'string' || !(data.paymentMethod in paymentStatuses)) {
    return fail('invalid-payment-state', 'Select a supported payment method.');
  }
  return {
    orderId: data.orderId,
    items,
    pickupAtMillis: pickupAtMillis as number,
    replacementPreference: data.replacementPreference as string,
    paymentMethod: data.paymentMethod,
  };
}

function sameSubmission(existing: RecordValue, input: PlaceInput, uid: string): boolean {
  const existingItems = existing.items;
  const pickup = existing.pickupAt;
  if (existing.stockReserved !== true || existing.status === 'cancelled'
    || existing.customerId !== uid || existing.paymentMethod !== input.paymentMethod
    || existing.replacementPreference !== input.replacementPreference
    || !(pickup instanceof Timestamp) || pickup.toMillis() !== input.pickupAtMillis
    || !Array.isArray(existingItems) || existingItems.length !== input.items.length) return false;
  return input.items.every((item, index) => {
    const stored = object(existingItems[index]);
    return stored?.productId === item.productId && stored.quantity === item.quantity;
  });
}

function requiredUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError('unauthenticated', 'Sign in to continue.', { reason: 'unauthenticated' });
  return uid;
}

export async function placeOrderCore(db: Firestore, callerUid: string | undefined, raw: unknown): Promise<{ orderId: string }> {
  const uid = requiredUid(callerUid);
  const input = parsePlaceInput(raw);
  const orderRef = db.collection('orders').doc(input.orderId);
  const userRef = db.collection('users').doc(uid);
  const productRefs = input.items.map((item) => db.collection('products').doc(item.productId));

  return db.runTransaction(async (tx) => {
    const user = await tx.get(userRef);
    if (!user.exists || user.get('role') !== 'customer') {
      return fail('not-customer', 'A customer account is required.', 'permission-denied');
    }
    const previous = await tx.get(orderRef);
    if (previous.exists) {
      if (!sameSubmission(previous.data() as RecordValue, input, uid)) {
        return fail('order-id-in-use', 'Start checkout again.', 'already-exists');
      }
      return { orderId: input.orderId };
    }

    const products = [];
    for (const ref of productRefs) products.push(await tx.get(ref));
    let shopId: string | null = null;
    let currencyCode: string | null = null;
    let shopName = '';
    let totalMinor = 0;
    const snapshots: RecordValue[] = [];
    const newStocks: number[] = [];
    for (let index = 0; index < products.length; index++) {
      const product = products[index];
      const quantity = input.items[index].quantity;
      if (!product.exists) return fail('product-not-found', 'A product is no longer available.', 'not-found');
      const data = product.data() as RecordValue;
      if (data.isActive === false) return fail('product-inactive', 'A product is no longer available.', 'failed-precondition');
      if (typeof data.shopId !== 'string' || !identifier(data.shopId)) {
        return fail('invalid-product', 'A product is unavailable.', 'failed-precondition');
      }
      if (shopId !== null && shopId !== data.shopId) {
        return fail('mixed-shop-cart', 'Place items from one store at a time.', 'failed-precondition');
      }
      shopId = data.shopId;
      const price = data.priceMinor;
      const stock = data.stockQuantity;
      if (!Number.isSafeInteger(price) || (price as number) <= 0
        || !Number.isSafeInteger(stock) || (stock as number) < 0
        || typeof data.name !== 'string' || data.name.length === 0) {
        return fail('invalid-product', 'A product is unavailable.', 'failed-precondition');
      }
      if ((stock as number) < quantity) {
        return fail('insufficient-stock', 'A product has insufficient stock. Review your cart.', 'failed-precondition');
      }
      const currency = typeof data.currencyCode === 'string' ? data.currencyCode : 'LKR';
      if (!/^[A-Z]{3}$/.test(currency) || (currencyCode !== null && currencyCode !== currency)) {
        return fail('invalid-product', 'Products use incompatible currencies.', 'failed-precondition');
      }
      currencyCode = currency;
      const lineTotal = (price as number) * quantity;
      totalMinor += lineTotal;
      if (!Number.isSafeInteger(lineTotal) || !Number.isSafeInteger(totalMinor)) {
        return fail('invalid-product', 'The order amount is too large.', 'failed-precondition');
      }
      newStocks.push((stock as number) - quantity);
      shopName = typeof data.shopName === 'string' ? data.shopName : shopName;
      snapshots.push({
        productId: product.id,
        productName: data.name,
        quantity,
        unitPriceMinor: price,
        lineTotalMinor: lineTotal,
        currencyCode: currency,
        imageUrl: typeof data.imageUrl === 'string' ? data.imageUrl : null,
        unit: typeof data.unit === 'string' ? data.unit : '',
      });
    }
    const shop = await tx.get(db.collection('users').doc(shopId!));
    if (!shop.exists || shop.get('role') !== 'shop' || shop.get('approvalStatus') !== 'approved') {
      return fail('shop-unavailable', 'This shop cannot currently accept orders.', 'failed-precondition');
    }
    if (typeof shop.get('shopName') === 'string' && shop.get('shopName').trim()) {
      shopName = shop.get('shopName');
    }
    const timestamp = FieldValue.serverTimestamp();
    tx.create(orderRef, {
      id: input.orderId,
      customerId: uid,
      shopId,
      shopName,
      items: snapshots,
      subtotalMinor: totalMinor,
      totalMinor,
      currencyCode,
      paymentMethod: input.paymentMethod,
      paymentStatus: paymentStatuses[input.paymentMethod],
      status: 'placed',
      pickupAt: Timestamp.fromMillis(input.pickupAtMillis),
      replacementPreference: input.replacementPreference,
      stockReserved: true,
      stockRestored: false,
      createdAt: timestamp,
      updatedAt: timestamp,
      acceptedAt: null,
      preparingAt: null,
      readyAt: null,
      collectedAt: null,
      cancelledAt: null,
      completedAt: null,
    });
    productRefs.forEach((ref, index) => {
      tx.update(ref, { stockQuantity: newStocks[index], updatedAt: FieldValue.serverTimestamp() });
    });
    return { orderId: input.orderId };
  });
}

type ReleaseRequest = { orderId: string; reason: string; note?: string };

function parseReleaseInput(raw: unknown, shop: boolean): ReleaseRequest {
  const data = object(raw);
  if (!data || !identifier(data.orderId)) return fail('invalid-order-id', 'Select a valid order.');
  if (shop) return { orderId: data.orderId, reason: 'shopRejected' };
  if (typeof data.reason !== 'string' || !cancellationReasons.has(data.reason)) {
    return fail('invalid-reason', 'Select a cancellation reason.');
  }
  if (data.note !== undefined && (typeof data.note !== 'string' || data.note.length > 500)) {
    return fail('invalid-note', 'The cancellation note is too long.');
  }
  return { orderId: data.orderId, reason: data.reason, note: data.note as string | undefined };
}

async function restoreReservedStock(db: Firestore, tx: Transaction, order: RecordValue): Promise<boolean> {
  if (order.stockReserved !== true) return false; // Legacy orders never deducted stock.
  if (order.stockRestored === true) return fail('already-restored', 'This order was already cancelled.', 'failed-precondition');
  if (!Array.isArray(order.items) || order.items.length === 0 || order.items.length > 100) {
    return fail('invalid-order', 'This order cannot be cancelled automatically.', 'failed-precondition');
  }
  const seen = new Set<string>();
  const refs: DocumentReference[] = [];
  const quantities: number[] = [];
  for (const value of order.items) {
    const item = object(value);
    if (!item || !identifier(item.productId) || !Number.isSafeInteger(item.quantity)
      || (item.quantity as number) < 1 || seen.has(item.productId as string)) {
      return fail('invalid-order', 'This order cannot be cancelled automatically.', 'failed-precondition');
    }
    seen.add(item.productId as string);
    refs.push(db.collection('products').doc(item.productId as string));
    quantities.push(item.quantity as number);
  }
  const values = [];
  for (const ref of refs) values.push(await tx.get(ref));
  values.forEach((value, index) => {
    const stock = value.get('stockQuantity');
    if (!value.exists || !Number.isSafeInteger(stock) || stock < 0
      || !Number.isSafeInteger(stock + quantities[index])) {
      return fail('invalid-stock', 'Stock could not be restored safely.', 'failed-precondition');
    }
    tx.update(refs[index], {
      stockQuantity: stock + quantities[index],
      updatedAt: FieldValue.serverTimestamp(),
    });
  });
  return true;
}

async function releaseOrderCore(db: Firestore, uid: string, input: ReleaseRequest, shopActor: boolean): Promise<{ orderId: string; alreadyCancelled: boolean }> {
  const orderRef = db.collection('orders').doc(input.orderId);
  return db.runTransaction(async (tx) => {
    const profile = await tx.get(db.collection('users').doc(uid));
    if (!profile.exists || profile.get('role') !== (shopActor ? 'shop' : 'customer')
      || (shopActor && profile.get('approvalStatus') !== 'approved')) {
      return fail(shopActor ? 'not-approved-shop' : 'not-customer', 'This account cannot cancel the order.', 'permission-denied');
    }
    const snapshot = await tx.get(orderRef);
    if (!snapshot.exists) return fail('order-not-found', 'This order is unavailable.', 'not-found');
    const order = snapshot.data() as RecordValue;
    if ((shopActor ? order.shopId : order.customerId) !== uid) {
      return fail('not-owner', 'This order is unavailable.', 'permission-denied');
    }
    if (order.status === 'cancelled') return { orderId: input.orderId, alreadyCancelled: true };
    if (shopActor ? order.status !== 'placed' : !customerCancelStatuses.has(order.status as string)) {
      return fail('not-cancellable', 'This order can no longer be cancelled.', 'failed-precondition');
    }
    const restored = await restoreReservedStock(db, tx, order);
    tx.update(orderRef, {
      status: 'cancelled',
      cancellationReason: input.reason,
      cancellationNote: input.note?.trim() || null,
      cancelledAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
      ...(restored ? { stockRestored: true } : {}),
    });
    return { orderId: input.orderId, alreadyCancelled: false };
  });
}

export async function cancelOrderCore(db: Firestore, callerUid: string | undefined, raw: unknown) {
  return releaseOrderCore(db, requiredUid(callerUid), parseReleaseInput(raw, false), false);
}

export async function rejectShopOrderCore(db: Firestore, callerUid: string | undefined, raw: unknown) {
  return releaseOrderCore(db, requiredUid(callerUid), parseReleaseInput(raw, true), true);
}
