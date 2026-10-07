'use strict';

const { test, before } = require('node:test');
const assert = require('node:assert/strict');

const project = 'demo-pikzen-orders';
const host = process.env.FIRESTORE_EMULATOR_HOST || '127.0.0.1:8087';
const base = `http://${host}/v1/projects/${project}/databases/(default)/documents`;
const name = path => `projects/${project}/databases/(default)/documents/${path}`;
const string = value => ({ stringValue: value });
const integer = value => ({ integerValue: String(value) });
const boolean = value => ({ booleanValue: value });
const nullValue = { nullValue: null };
const future = () => ({ timestampValue: new Date(Date.now() + 86400000).toISOString() });

function token(uid) {
  const encode = value => Buffer.from(JSON.stringify(value)).toString('base64url');
  return `${encode({ alg: 'none', typ: 'JWT' })}.${encode({
    sub: uid,
    user_id: uid,
    email: `${uid}@example.com`,
    aud: project,
    iss: `https://securetoken.google.com/${project}`,
    iat: Math.floor(Date.now() / 1000),
    exp: Math.floor(Date.now() / 1000) + 3600,
    firebase: { sign_in_provider: 'password', identities: {} },
  })}.`;
}

async function commit(actor, writes) {
  const response = await fetch(`${base}:commit`, {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${actor === 'owner' ? 'owner' : token(actor)}`,
    },
    body: JSON.stringify({ writes }),
  });
  return { status: response.status, body: await response.json() };
}

async function read(actor, path) {
  const response = await fetch(`${base}/${path}`, {
    headers: { Authorization: `Bearer ${actor === 'owner' ? 'owner' : token(actor)}` },
  });
  return { status: response.status, body: await response.json() };
}

function create(path, fields, timestamps = []) {
  return {
    update: { name: name(path), fields },
    currentDocument: { exists: false },
    updateTransforms: timestamps.map(fieldPath => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    })),
  };
}

function update(path, fields, timestamps = []) {
  return {
    update: { name: name(path), fields },
    updateMask: { fieldPaths: Object.keys(fields) },
    currentDocument: { exists: true },
    updateTransforms: timestamps.map(fieldPath => ({
      fieldPath,
      setToServerValue: 'REQUEST_TIME',
    })),
  };
}

function user(uid, role, approvalStatus) {
  return create(`users/${uid}`, {
    uid: string(uid), role: string(role),
    ...(approvalStatus ? { approvalStatus: string(approvalStatus) } : {}),
  });
}

function product(id, stock) {
  return create(`products/${id}`, {
    name: string(id), category: string('Fruits'), priceMinor: integer(45000),
    stockQuantity: integer(stock), currencyCode: string('LKR'),
    shopId: string('shop'), shopName: string('Test shop'), isActive: boolean(true),
  }, ['createdAt', 'updatedAt']);
}

function order(id, method, quantity, productId = 'apple') {
  const total = 45000 * quantity;
  return create(`orders/${id}`, {
    id: string(id), customerId: string('customer'), shopId: string('shop'),
    shopName: string('Test shop'),
    items: { arrayValue: { values: [{ mapValue: { fields: {
      productId: string(productId), productName: string(productId),
      quantity: integer(quantity), unitPriceMinor: integer(45000),
      lineTotalMinor: integer(total), currencyCode: string('LKR'),
      imageUrl: nullValue, unit: nullValue,
    } } }] } },
    stockQuantities: { mapValue: { fields: { [productId]: integer(quantity) } } },
    subtotalMinor: integer(total), totalMinor: integer(total),
    currencyCode: string('LKR'), paymentMethod: string(method),
    paymentStatus: string(method === 'cashOnPickup' ? 'unpaid' : 'demo'),
    status: string('placed'), pickupAt: future(),
    replacementPreference: string('allowReplacement'),
    stockReserved: boolean(true), stockRestored: boolean(false),
    acceptedAt: nullValue, preparingAt: nullValue, readyAt: nullValue,
    collectedAt: nullValue, cancelledAt: nullValue, completedAt: nullValue,
  }, ['createdAt', 'updatedAt']);
}

function stock(id, value, orderId, kind) {
  return update(`products/${id}`, {
    stockQuantity: integer(value), stockChangeOrderId: string(orderId),
    stockChangeKind: string(kind),
  }, ['updatedAt']);
}

function cancellation(id, reason) {
  return update(`orders/${id}`, {
    status: string('cancelled'), cancellationReason: string(reason),
    cancellationNote: nullValue, stockRestored: boolean(true),
  }, ['updatedAt', 'cancelledAt']);
}

before(async () => {
  const cleared = await fetch(
    `http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  assert.equal(cleared.status, 200);
  const seeded = await commit('owner', [
    user('customer', 'customer'), user('other', 'customer'),
    user('shop', 'shop', 'approved'), user('pending', 'shop', 'pending'),
    product('apple', 5), product('pear', 2),
  ]);
  assert.equal(seeded.status, 200, JSON.stringify(seeded.body));
});

test('customer checkout cannot read private shop profile or a new order', async () => {
  assert.equal((await read('customer', 'users/shop')).status, 403);
  assert.equal((await read('customer', 'orders/not-created-yet')).status, 403);
  assert.equal((await read('customer', 'users/customer')).status, 200);
});

test('demo card order reserves stock atomically', async () => {
  const saved = await commit('customer', [
    order('card-order', 'card', 2), stock('apple', 3, 'card-order', 'reserved'),
  ]);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  assert.equal((await read('owner', 'products/apple')).body.fields.stockQuantity.integerValue, '3');
  assert.equal((await read('customer', 'orders/card-order')).body.fields.paymentStatus.stringValue, 'demo');
  assert.equal((await read('other', 'orders/card-order')).status, 403);
});

test('cash order stays unpaid and reserves stock', async () => {
  const saved = await commit('customer', [
    order('cash-order', 'cashOnPickup', 1, 'pear'),
    stock('pear', 1, 'cash-order', 'reserved'),
  ]);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  assert.equal((await read('customer', 'orders/cash-order')).body.fields.paymentStatus.stringValue, 'unpaid');
});

test('failed stock reservation cannot create a partial order', async () => {
  const failed = await commit('customer', [
    order('oversold-order', 'card', 4, 'pear'),
    stock('pear', -3, 'oversold-order', 'reserved'),
  ]);
  assert.equal(failed.status, 403, JSON.stringify(failed.body));
  assert.equal((await read('owner', 'orders/oversold-order')).status, 404);
  assert.equal((await read('owner', 'products/pear')).body.fields.stockQuantity.integerValue, '1');
});

test('stock cannot be changed without its linked order', async () => {
  const changed = await commit('customer', [stock('apple', 2, 'missing-order', 'reserved')]);
  assert.equal(changed.status, 403, JSON.stringify(changed.body));
});

test('an order without the matching stock write is denied', async () => {
  const created = await commit('customer', [order('phantom-order', 'card', 1)]);
  assert.equal(created.status, 403, JSON.stringify(created.body));
});

test('the order total must match current product prices', async () => {
  const forged = order('wrong-price-order', 'card', 1);
  forged.update.fields.totalMinor = integer(1);
  forged.update.fields.subtotalMinor = integer(1);
  const saved = await commit('customer', [
    forged, stock('apple', 4, 'wrong-price-order', 'reserved'),
  ]);
  assert.equal(saved.status, 403, JSON.stringify(saved.body));
  assert.equal((await read('owner', 'products/apple')).body.fields.stockQuantity.integerValue, '3');
});

test('another customer cannot forge ownership', async () => {
  const forged = await commit('other', [order('forged-order', 'card', 1)]);
  assert.equal(forged.status, 403, JSON.stringify(forged.body));
});

test('customer cancellation restores stock once', async () => {
  const other = await commit('other', [
    cancellation('card-order', 'changedMind'),
    stock('apple', 5, 'card-order', 'restored'),
  ]);
  assert.equal(other.status, 403, JSON.stringify(other.body));
  const cancelled = await commit('customer', [
    cancellation('card-order', 'changedMind'),
    stock('apple', 5, 'card-order', 'restored'),
  ]);
  assert.equal(cancelled.status, 200, JSON.stringify(cancelled.body));
  assert.equal((await read('owner', 'products/apple')).body.fields.stockQuantity.integerValue, '5');
  assert.equal((await read('owner', 'orders/card-order')).body.fields.stockRestored.booleanValue, true);
  const again = await commit('customer', [
    cancellation('card-order', 'changedMind'),
    stock('apple', 7, 'card-order', 'restored'),
  ]);
  assert.equal(again.status, 403, JSON.stringify(again.body));
  assert.equal((await read('owner', 'products/apple')).body.fields.stockQuantity.integerValue, '5');
});

test('approved shop can reject a placed order and restore stock', async () => {
  const denied = await commit('pending', [cancellation('cash-order', 'shopRejected')]);
  assert.equal(denied.status, 403, JSON.stringify(denied.body));
  const rejected = await commit('shop', [
    cancellation('cash-order', 'shopRejected'),
    stock('pear', 2, 'cash-order', 'restored'),
  ]);
  assert.equal(rejected.status, 200, JSON.stringify(rejected.body));
  assert.equal((await read('owner', 'products/pear')).body.fields.stockQuantity.integerValue, '2');
});

test('multiple products reserve and restore together', async () => {
  const combined = order('mixed-order', 'cashOnPickup', 1);
  const second = order('unused', 'cashOnPickup', 1, 'pear')
    .update.fields.items.arrayValue.values[0];
  combined.update.fields.items.arrayValue.values.push(second);
  combined.update.fields.stockQuantities.mapValue.fields.pear = integer(1);
  combined.update.fields.subtotalMinor = integer(90000);
  combined.update.fields.totalMinor = integer(90000);
  const saved = await commit('customer', [
    combined, stock('apple', 4, 'mixed-order', 'reserved'),
    stock('pear', 1, 'mixed-order', 'reserved'),
  ]);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  const cancelled = await commit('customer', [
    cancellation('mixed-order', 'changedMind'),
    stock('apple', 5, 'mixed-order', 'restored'),
    stock('pear', 2, 'mixed-order', 'restored'),
  ]);
  assert.equal(cancelled.status, 200, JSON.stringify(cancelled.body));
  assert.equal((await read('owner', 'products/apple')).body.fields.stockQuantity.integerValue, '5');
  assert.equal((await read('owner', 'products/pear')).body.fields.stockQuantity.integerValue, '2');
});

test('four products fit Firestore rules access limits', async () => {
  const ids = Array.from({ length: 4 }, (_, index) => `four-${index}`);
  const seeded = await commit('owner', ids.map(id => product(id, 2)));
  assert.equal(seeded.status, 200, JSON.stringify(seeded.body));
  const combined = order('four-order', 'card', 1, ids[0]);
  combined.update.fields.items.arrayValue.values = ids.map(id =>
    order('unused', 'card', 1, id).update.fields.items.arrayValue.values[0]);
  combined.update.fields.stockQuantities.mapValue.fields =
    Object.fromEntries(ids.map(id => [id, integer(1)]));
  combined.update.fields.subtotalMinor = integer(180000);
  combined.update.fields.totalMinor = integer(180000);
  const saved = await commit('customer', [
    combined, ...ids.map(id => stock(id, 1, 'four-order', 'reserved')),
  ]);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  const cancelled = await commit('customer', [
    cancellation('four-order', 'changedMind'),
    ...ids.map(id => stock(id, 2, 'four-order', 'restored')),
  ]);
  assert.equal(cancelled.status, 200, JSON.stringify(cancelled.body));
});
