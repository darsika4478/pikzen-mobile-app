'use strict';

// Emulator tests for demo payments, order chat, favourites and order-event
// notifications. Run with the Firestore emulator (see scripts/README.md).
const { test, before } = require('node:test');
const assert = require('node:assert/strict');

const project = 'demo-pikzen-backend';
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

const auth = actor => `Bearer ${actor === 'owner' ? 'owner' : token(actor)}`;

async function commit(actor, writes) {
  const response = await fetch(`${base}:commit`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', Authorization: auth(actor) },
    body: JSON.stringify({ writes }),
  });
  return { status: response.status, body: await response.json() };
}

async function read(actor, path) {
  const response = await fetch(`${base}/${path}`, { headers: { Authorization: auth(actor) } });
  return { status: response.status, body: await response.json() };
}

const transforms = timestamps => timestamps.map(fieldPath => ({
  fieldPath, setToServerValue: 'REQUEST_TIME',
}));

function create(path, fields, timestamps = []) {
  return {
    update: { name: name(path), fields },
    currentDocument: { exists: false },
    updateTransforms: transforms(timestamps),
  };
}

function update(path, fields, timestamps = []) {
  return {
    update: { name: name(path), fields },
    updateMask: { fieldPaths: Object.keys(fields) },
    currentDocument: { exists: true },
    updateTransforms: transforms(timestamps),
  };
}

const remove = path => ({ delete: name(path) });

function user(uid, role, extra = {}) {
  return create(`users/${uid}`, { uid: string(uid), role: string(role), ...extra });
}

function product(id, stock) {
  return create(`products/${id}`, {
    name: string(id), category: string('Fruits'), priceMinor: integer(45000),
    stockQuantity: integer(stock), currencyCode: string('LKR'),
    shopId: string('shop'), shopName: string('Test shop'), isActive: boolean(true),
  }, ['createdAt', 'updatedAt']);
}

function line(productId, quantity) {
  return { mapValue: { fields: {
    productId: string(productId), productName: string(productId),
    quantity: integer(quantity), unitPriceMinor: integer(45000),
    lineTotalMinor: integer(45000 * quantity), currencyCode: string('LKR'),
    imageUrl: nullValue, unit: nullValue,
  } } };
}

function order(id, method, productIds, extra = {}) {
  const total = 45000 * productIds.length;
  return create(`orders/${id}`, {
    id: string(id), customerId: string('customer'), shopId: string('shop'),
    shopName: string('Test shop'),
    items: { arrayValue: { values: productIds.map(productId => line(productId, 1)) } },
    stockQuantities: { mapValue: { fields: Object.fromEntries(
      productIds.map(productId => [productId, integer(1)])) } },
    subtotalMinor: integer(total), totalMinor: integer(total),
    currencyCode: string('LKR'), paymentMethod: string(method),
    paymentStatus: string(method === 'cashOnPickup' ? 'unpaid' : 'demo'),
    status: string('placed'), pickupAt: future(),
    replacementPreference: string('allowReplacement'),
    stockReserved: boolean(true), stockRestored: boolean(false),
    acceptedAt: nullValue, preparingAt: nullValue, readyAt: nullValue,
    collectedAt: nullValue, cancelledAt: nullValue, completedAt: nullValue,
    customerName: string('Demo Customer'), customerPhone: string('+94770000001'),
    ...extra,
  }, ['createdAt', 'updatedAt']);
}

function reserve(productId, orderId, stockAfter) {
  return update(`products/${productId}`, {
    stockQuantity: integer(stockAfter), stockChangeOrderId: string(orderId),
    stockChangeKind: string('reserved'),
  }, ['updatedAt']);
}

function payment(id, method, amount, extra = {}) {
  return create(`payments/${id}`, {
    id: string(id), orderId: string(id), customerId: string('customer'),
    shopId: string('shop'), method: string(method),
    provider: method === 'card' ? string('Demo card') : nullValue,
    cardLast4: method === 'card' ? string('4242') : nullValue,
    amountMinor: integer(amount), currencyCode: string('LKR'),
    status: string(method === 'cashOnPickup' ? 'pending' : 'demo_paid'),
    reference: string(`DEMO-${id.toUpperCase()}`), isDemo: boolean(true),
    ...extra,
  }, ['createdAt']);
}

// Places a one-product order with its stock reservation and payment receipt.
async function place(id, productId, method = 'card') {
  const placed = await commit('customer', [
    order(id, method, [productId]), reserve(productId, id, 4), payment(id, method, 45000),
  ]);
  assert.equal(placed.status, 200, JSON.stringify(placed.body));
}

function notification(id, orderId, type, message = 'Update') {
  return create(`notifications/${id}`, {
    id: string(id), userId: string('customer'), type: string(type),
    title: string(type), message: string(message), orderId: string(orderId),
    productId: nullValue, isRead: boolean(false),
  }, ['createdAt']);
}

function chat(orderId, id, sender, role, text = 'Hello') {
  return create(`orders/${orderId}/messages/${id}`, {
    id: string(id), senderId: string(sender), senderRole: string(role), text: string(text),
  }, ['createdAt']);
}

before(async () => {
  const cleared = await fetch(
    `http://${host}/emulator/v1/projects/${project}/databases/(default)/documents`,
    { method: 'DELETE' },
  );
  assert.equal(cleared.status, 200);
  const seeded = await commit('owner', [
    user('customer', 'customer', {
      fullName: string('Demo Customer'), phone: string('+94770000001'),
    }),
    user('other', 'customer', { fullName: string('Other Customer') }),
    user('shop', 'shop', { approvalStatus: string('approved') }),
    user('rival', 'shop', { approvalStatus: string('approved') }),
    user('admin', 'admin'), user('promoted', 'customer'),
    user('victim', 'customer', {
      fullName: string('Demo Customer'), phone: string('+94770000001'),
    }),
    user('admin2', 'admin'),
    ...['p1', 'p2', 'p3', 'p4', 'p5', 'p6', 'p7', 'p8', 'p9'].map(id => product(id, 5)),
  ]);
  assert.equal(seeded.status, 200, JSON.stringify(seeded.body));
});

test('card order saves a demo receipt with only the last four digits', async () => {
  await place('pay-card', 'p1');
  const receipt = await read('customer', 'payments/pay-card');
  assert.equal(receipt.status, 200);
  assert.equal(receipt.body.fields.cardLast4.stringValue, '4242');
  assert.equal(receipt.body.fields.status.stringValue, 'demo_paid');
  assert.equal((await read('shop', 'payments/pay-card')).status, 200);
  assert.equal((await read('other', 'payments/pay-card')).status, 403);
  assert.equal((await read('rival', 'payments/pay-card')).status, 403);
  // The shop sees the customer's contact snapshot on the order.
  const seen = await read('shop', 'orders/pay-card');
  assert.equal(seen.body.fields.customerName.stringValue, 'Demo Customer');
});

test('a receipt must match its order amount and cannot be deleted', async () => {
  const wrong = await commit('customer', [
    order('pay-wrong', 'card', ['p2']), reserve('p2', 'pay-wrong', 4),
    payment('pay-wrong', 'card', 1),
  ]);
  assert.equal(wrong.status, 403, JSON.stringify(wrong.body));
  await place('pay-late', 'p2');
  const replaced = await commit('customer', [remove('payments/pay-late')]);
  assert.equal(replaced.status, 403);
});

test('a receipt cannot carry a full card number or fake a cash payment', async () => {
  const leaked = await commit('customer', [
    order('pay-leak', 'card', ['p3']), reserve('p3', 'pay-leak', 4),
    payment('pay-leak', 'card', 45000, { cardLast4: string('4242424242424242') }),
  ]);
  assert.equal(leaked.status, 403, JSON.stringify(leaked.body));
  const fakeCash = await commit('customer', [
    order('pay-fake', 'cashOnPickup', ['p3']), reserve('p3', 'pay-fake', 4),
    payment('pay-fake', 'cashOnPickup', 45000, { status: string('paid') }),
  ]);
  assert.equal(fakeCash.status, 403, JSON.stringify(fakeCash.body));
});

test('the order contact snapshot must match the customer profile', async () => {
  const forged = await commit('customer', [
    order('forged-name', 'card', ['p4'], { customerName: string('Someone Else') }),
    reserve('p4', 'forged-name', 4), payment('forged-name', 'card', 45000),
  ]);
  assert.equal(forged.status, 403, JSON.stringify(forged.body));
});

test('four products with a receipt fit the rules access limits', async () => {
  const ids = ['p5', 'p6', 'p7', 'p8'];
  const placed = await commit('customer', [
    order('pay-four', 'card', ids), ...ids.map(id => reserve(id, 'pay-four', 4)),
    payment('pay-four', 'card', 180000),
  ]);
  assert.equal(placed.status, 200, JSON.stringify(placed.body));
});

test('cash is settled only when the shop marks the order collected', async () => {
  await place('cash-flow', 'p9', 'cashOnPickup');
  const early = await commit('shop', [
    update('orders/cash-flow', { status: string('accepted'), paymentStatus: string('paid') },
      ['updatedAt', 'acceptedAt']),
  ]);
  assert.equal(early.status, 403, JSON.stringify(early.body));
  for (const [status, stamp] of [['accepted', 'acceptedAt'], ['preparing', 'preparingAt'], ['ready', 'readyAt']]) {
    const moved = await commit('shop', [
      update('orders/cash-flow', { status: string(status) }, ['updatedAt', stamp]),
    ]);
    assert.equal(moved.status, 200, JSON.stringify(moved.body));
  }
  const customerPaid = await commit('customer', [
    update('payments/cash-flow', { status: string('paid') }, ['paidAt']),
  ]);
  assert.equal(customerPaid.status, 403);
  const collected = await commit('shop', [
    update('orders/cash-flow', { status: string('collected'), paymentStatus: string('paid') },
      ['updatedAt', 'collectedAt', 'completedAt']),
    update('payments/cash-flow', { status: string('paid') }, ['paidAt']),
  ]);
  assert.equal(collected.status, 200, JSON.stringify(collected.body));
  assert.equal((await read('customer', 'payments/cash-flow')).body.fields.status.stringValue, 'paid');
});

test('order chat is limited to the customer and shop of the order', async () => {
  const customer = await commit('customer', [chat('pay-card', 'c1', 'customer', 'customer')]);
  assert.equal(customer.status, 200, JSON.stringify(customer.body));
  const spoofed = await commit('customer', [chat('pay-card', 'c2', 'customer', 'shop')]);
  assert.equal(spoofed.status, 403);
  const outsider = await commit('other', [chat('pay-card', 'c3', 'other', 'customer')]);
  assert.equal(outsider.status, 403);
  assert.equal((await read('shop', 'orders/pay-card/messages/c1')).status, 200);
  assert.equal((await read('rival', 'orders/pay-card/messages/c1')).status, 403);
  const edited = await commit('customer', [
    update('orders/pay-card/messages/c1', { text: string('Changed') }),
  ]);
  assert.equal(edited.status, 403);
});

test('a shop message notifies the customer once, with the message', async () => {
  const sent = await commit('shop', [
    chat('pay-card', 's1', 'shop', 'shop', 'Your order is being packed.'),
    notification('s1', 'pay-card', 'SHOP_MESSAGE', 'Your order is being packed.'),
  ]);
  assert.equal(sent.status, 200, JSON.stringify(sent.body));
  assert.equal((await read('customer', 'notifications/s1')).status, 200);
  const orphan = await commit('shop', [
    notification('s9', 'pay-card', 'SHOP_MESSAGE', 'No message behind this'),
  ]);
  assert.equal(orphan.status, 403);
  const rival = await commit('rival', [
    chat('pay-card', 's2', 'rival', 'shop'), notification('s2', 'pay-card', 'SHOP_MESSAGE'),
  ]);
  assert.equal(rival.status, 403);
});

test('shops can check for an existing order event before sending one', async () => {
  assert.equal((await read('shop', 'notifications/pay-card_ORDER_ACCEPTED')).status, 404);
  const accepted = await commit('shop', [
    update('orders/pay-card', { status: string('accepted') }, ['updatedAt', 'acceptedAt']),
    notification('pay-card_ORDER_ACCEPTED', 'pay-card', 'ORDER_ACCEPTED'),
  ]);
  assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
  assert.equal((await read('shop', 'notifications/pay-card_ORDER_ACCEPTED')).status, 200);
  assert.equal((await read('rival', 'notifications/pay-card_ORDER_ACCEPTED')).status, 403);
});

test('a shop rejection notifies the customer', async () => {
  const rejected = await commit('shop', [
    update('orders/pay-late', {
      status: string('cancelled'), cancellationReason: string('shopRejected'),
      cancellationNote: nullValue, stockRestored: boolean(true),
    }, ['updatedAt', 'cancelledAt']),
    update('products/p2', {
      stockQuantity: integer(5), stockChangeOrderId: string('pay-late'),
      stockChangeKind: string('restored'),
    }, ['updatedAt']),
    notification('pay-late_ORDER_REJECTED', 'pay-late', 'ORDER_REJECTED'),
  ]);
  assert.equal(rejected.status, 200, JSON.stringify(rejected.body));
  const premature = await commit('shop', [
    notification('pay-four_ORDER_REJECTED', 'pay-four', 'ORDER_REJECTED'),
  ]);
  assert.equal(premature.status, 403);
});

test('favourites are private to their owner', async () => {
  const saved = await commit('customer', [
    create('users/customer/favourites/p1', { productId: string('p1') }, ['createdAt']),
  ]);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  assert.equal((await read('customer', 'users/customer/favourites/p1')).status, 200);
  assert.equal((await read('other', 'users/customer/favourites/p1')).status, 403);
  const planted = await commit('other', [
    create('users/customer/favourites/p2', { productId: string('p2') }, ['createdAt']),
  ]);
  assert.equal(planted.status, 403);
  const mismatched = await commit('customer', [
    create('users/customer/favourites/p3', { productId: string('p4') }, ['createdAt']),
  ]);
  assert.equal(mismatched.status, 403);
  assert.equal((await commit('customer', [remove('users/customer/favourites/p1')])).status, 200);
});

test('a pickup code must be four digits', async () => {
  const bad = await commit('customer', [
    order('code-bad', 'card', ['p6'], { pickupCode: string('12a4') }),
    reserve('p6', 'code-bad', 3), payment('code-bad', 'card', 45000),
  ]);
  assert.equal(bad.status, 403, JSON.stringify(bad.body));
  const good = await commit('customer', [
    order('code-ok', 'card', ['p6'], { pickupCode: string('0427') }),
    reserve('p6', 'code-ok', 3), payment('code-ok', 'card', 45000),
  ]);
  assert.equal(good.status, 200, JSON.stringify(good.body));
});

test('customers check in once, and only after the shop accepts', async () => {
  const checkIn = () => update('orders/code-ok', {}, ['arrivedAt']);
  const early = await commit('customer', [checkIn()]);
  assert.equal(early.status, 403, 'placed orders cannot be checked in');
  const accepted = await commit('shop', [
    update('orders/code-ok', { status: string('accepted') }, ['updatedAt', 'acceptedAt']),
  ]);
  assert.equal(accepted.status, 200, JSON.stringify(accepted.body));
  assert.equal((await commit('other', [checkIn()])).status, 403);
  const arrived = await commit('customer', [checkIn()]);
  assert.equal(arrived.status, 200, JSON.stringify(arrived.body));
  assert.equal((await commit('customer', [checkIn()])).status, 403, 'only once');
  const forged = await commit('customer', [
    update('orders/code-ok', { status: string('ready') }, ['arrivedAt']),
  ]);
  assert.equal(forged.status, 403);
});

test('profile photos must be small inline images owned by the user', async () => {
  const tiny = 'data:image/jpeg;base64,' + Buffer.from([0xff, 0xd8, 0xff, 0xd9]).toString('base64');
  const photo = value => update('users/customer', { photoUrl: string(value) });
  assert.equal((await commit('customer', [photo(tiny)])).status, 200);
  assert.equal((await commit('other', [photo(tiny)])).status, 403, 'not the owner');
  assert.equal((await commit('customer', [photo('https://evil.example/x.png')])).status, 403);
  assert.equal((await commit('customer', [photo('data:image/jpeg;base64,' + 'A'.repeat(150000))])).status, 403);
  assert.equal((await commit('customer', [photo('')])).status, 200, 'removal');
});

test('admins suspend and reactivate accounts; suspended customers cannot order', async () => {
  const status = value => update('users/victim', { accountStatus: string(value) });
  assert.equal((await commit('victim', [status('active')])).status, 403, 'not self-service');
  assert.equal((await commit('customer', [status('suspended')])).status, 403, 'not by customers');
  assert.equal((await commit('admin', [status('suspended')])).status, 200);
  const victimOrder = () => {
    const write = order('victim-order', 'card', ['p8']);
    write.update.fields.customerId = string('victim');
    const receipt = payment('victim-order', 'card', 45000);
    receipt.update.fields.customerId = string('victim');
    return [write, reserve('p8', 'victim-order', 3), receipt];
  };
  assert.equal((await commit('victim', victimOrder())).status, 403, 'suspended');
  assert.equal((await commit('admin', [status('active')])).status, 200);
  const placed = await commit('victim', victimOrder());
  assert.equal(placed.status, 200, JSON.stringify(placed.body));
});

test('admins cannot suspend themselves or other admins', async () => {
  const suspend = id => update(`users/${id}`, { accountStatus: string('suspended') });
  assert.equal((await commit('admin', [suspend('admin')])).status, 403);
  assert.equal((await commit('admin', [suspend('admin2')])).status, 403);
});

test('admins move accounts between customer and approved shop', async () => {
  const toShop = update('users/promoted', {
    role: string('shop'), approvalStatus: string('approved'),
  });
  assert.equal((await commit('customer', [toShop])).status, 403, 'not by customers');
  assert.equal((await commit('admin', [toShop])).status, 200);
  const toAdmin = update('users/promoted', { role: string('admin') });
  assert.equal((await commit('admin', [toAdmin])).status, 403, 'never grants admin');
  const back = {
    update: { name: name('users/promoted'), fields: { role: string('customer') } },
    updateMask: { fieldPaths: ['role', 'approvalStatus'] },
    currentDocument: { exists: true },
  };
  assert.equal((await commit('admin', [back])).status, 200);
});

test('shops and customers save only their own notification preference keys', async () => {
  const prefs = (id, fields) => update(`users/${id}`, {
    preferences: { mapValue: { fields } },
  });
  const shopPrefs = prefs('shop', {
    newOrderAlerts: boolean(false), lowStockAlerts: boolean(true),
  });
  shopPrefs.update.fields.fullName = string('Test Shop Owner');
  shopPrefs.updateMask.fieldPaths.push('fullName');
  const saved = await commit('shop', [shopPrefs]);
  assert.equal(saved.status, 200, JSON.stringify(saved.body));
  assert.equal((await commit('customer', [prefs('customer', {
    newOrderAlerts: boolean(false),
  })])).status, 403, 'shop keys are not customer keys');
  assert.equal((await commit('customer', [prefs('customer', {
    pushNotifications: boolean(true),
  })])).status, 200);
});

test('product photos must be assets, https or small inline images', async () => {
  const photo = value => update('products/p9', { imageUrl: string(value) }, ['updatedAt']);
  const tiny = 'data:image/png;base64,' + Buffer.from([0x89, 0x50, 0x4e, 0x47]).toString('base64');
  assert.equal((await commit('shop', [photo(tiny)])).status, 200);
  assert.equal((await commit('shop', [photo('https://example.com/a.jpg')])).status, 200);
  assert.equal((await commit('shop', [photo('http://example.com/a.jpg')])).status, 403);
  assert.equal((await commit('shop', [photo('data:image/png;base64,' + 'A'.repeat(400000))])).status, 403);
  assert.equal((await commit('rival', [photo(tiny)])).status, 403, 'not the owner');
});
