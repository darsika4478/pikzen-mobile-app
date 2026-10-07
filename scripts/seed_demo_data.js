'use strict';

// Local operator utility: seeds dummy accounts, products and orders for the
// campus demo. Never import this file into Flutter. All data is fictional and
// payments are simulated receipts (status demo_paid / pending), never real.
const readline = require('node:readline');
const { Writable } = require('node:stream');

class SeedError extends Error {}

const SHOP_NAME = 'PikZen Demo Mart';

const ACCOUNTS = [
  { key: 'customer', email: 'demo.customer@pikzen.test', fullName: 'Demo Customer', phone: '+94770000001', role: 'customer' },
  { key: 'shop', email: 'demo.shop@pikzen.test', fullName: 'Demo Shop Owner', phone: '+94770000002', role: 'shop', approvalStatus: 'approved', shopName: SHOP_NAME, storeAddress: '12 Campus Road, Colombo 07' },
  { key: 'pendingShop', email: 'demo.pending@pikzen.test', fullName: 'Pending Shop Owner', phone: '+94770000003', role: 'shop', approvalStatus: 'pending' },
  { key: 'admin', email: 'demo.admin@pikzen.test', fullName: 'Demo Administrator', phone: '', role: 'admin' },
];

// [id, name, category, priceMinor (LKR cents), stock, unit, image, description]
const PRODUCTS = [
  ['demo-red-apples', 'Royal Red Apples', 'Fruits', 95000, 40, '1kg', 'Royal redapple.png', 'Crisp Royal Gala apples.'],
  ['demo-green-apples', 'Green Apples', 'Fruits', 110000, 25, '1kg', 'Greeny apple.png', 'Tart Granny Smith apples.'],
  ['demo-organic-apples', 'Organic Apples', 'Fruits', 135000, 4, '1kg', 'Organic apple.png', 'Certified organic apples (low stock demo).'],
  ['demo-carrots', 'Fresh Carrots', 'Vegetables', 32000, 60, '500g', 'Carrot.png', 'Nuwara Eliya carrots.'],
  ['demo-leeks', 'Leeks', 'Vegetables', 28000, 35, '500g', 'Leeks.png', 'Fresh upcountry leeks.'],
  ['demo-tomatoes', 'Tomatoes', 'Vegetables', 36000, 0, '500g', 'Tomato.png', 'Ripe red tomatoes (out of stock demo).'],
  ['demo-whole-milk', 'Fresh Whole Milk', 'Dairy & Eggs', 52000, 30, '1L', 'Milk Product.png', 'Chilled whole milk.'],
  ['demo-cheese', 'Cheddar Cheese', 'Dairy & Eggs', 98000, 15, '200g', 'Cheese with milk.png', 'Mild cheddar block.'],
  ['demo-eggs', 'Farm Fresh Eggs', 'Dairy & Eggs', 48000, 50, 'Pack of 10', 'Eggs Product.png', 'Brown farm eggs.'],
  ['demo-roast-bun', 'Roast Bun', 'Bakery', 12000, 40, 'Pack of 4', 'Roast bun.png', 'Freshly baked roast buns.'],
  ['demo-chicken-puff', 'Chicken Puff', 'Bakery', 18000, 20, '1 piece', 'Chicken puff.png', 'Flaky pastry with spicy chicken.'],
  ['demo-orange-juice', 'Fresh Orange Juice', 'Beverages', 65000, 18, '1L', 'Fresh orange juice.png', 'Cold-pressed orange juice.'],
  ['demo-lemon-crush', 'Lemon Crush', 'Beverages', 42000, 22, '750ml', 'Lemon crush.png', 'Lemon cordial.'],
  ['demo-choc-cookies', 'Chocolate Cookies', 'Snacks & Bites', 39000, 45, '200g', 'Choc cookies.png', 'Chocolate chip cookies.'],
  ['demo-mixed-nuts', 'Mixed Nuts', 'Snacks & Bites', 125000, 12, '250g', 'Nuts nutri.png', 'Roasted cashew and almond mix.'],
  ['demo-dishwash', 'Dishwash Liquid', 'Household', 56000, 30, '500ml', 'Vim liquid.png', 'Lemon dishwash liquid.'],
  ['demo-laundry', 'Laundry Liquid', 'Household', 89000, 16, '1L', 'Washing liquid.png', 'Concentrated laundry liquid.'],
  ['demo-samba-rice', 'Keeri Samba Rice', 'Pantry Staples', 145000, 25, '5kg', 'Rice Product.png', 'Keeri Samba rice.'],
  ['demo-macaroni', 'Macaroni', 'Pantry Staples', 33000, 40, '400g', 'Macaroni.png', 'Elbow macaroni pasta.'],
];

// [orderId, status, paymentMethod, provider, cardLast4, [[productId, qty]], hoursUntilPickup]
const ORDERS = [
  ['demo-order-placed', 'placed', 'card', 'Demo card', '4242', [['demo-red-apples', 2], ['demo-whole-milk', 1]], 26],
  ['demo-order-preparing', 'preparing', 'cashOnPickup', null, null, [['demo-samba-rice', 1], ['demo-eggs', 2]], 5],
  ['demo-order-ready', 'ready', 'ewallet', 'FriMi', null, [['demo-orange-juice', 1], ['demo-choc-cookies', 3]], 2],
];

function validatePassword(password) {
  if (typeof password !== 'string' || password.length < 8) {
    throw new SeedError('The demo password must contain at least 8 characters.');
  }
  return password;
}

async function ensureAccount(auth, account, password) {
  try {
    return { user: await auth.getUserByEmail(account.email), created: false };
  } catch (error) {
    if (error.code !== 'auth/user-not-found') throw error;
  }
  const user = await auth.createUser({
    email: account.email, password, displayName: account.fullName, emailVerified: true,
  });
  return { user, created: true };
}

function profileFor(account, uid, now) {
  const profile = {
    uid, fullName: account.fullName, email: account.email,
    phone: account.phone, role: account.role, createdAt: now,
  };
  if (account.approvalStatus) profile.approvalStatus = account.approvalStatus;
  if (account.shopName) profile.shopName = account.shopName;
  if (account.storeAddress) profile.storeAddress = account.storeAddress;
  return profile;
}

function productDoc([, name, category, priceMinor, stockQuantity, unit, image, description], shopId, now) {
  return {
    name, category, priceMinor, currencyCode: 'LKR', stockQuantity,
    lowStockThreshold: 5, unit, description, imageUrl: `assets/images/${image}`,
    shopId, shopName: SHOP_NAME, isActive: true, createdAt: now, updatedAt: now,
  };
}

function orderDocs(spec, uids, products, { now, Timestamp }) {
  const [id, status, method, provider, cardLast4, lines, hours] = spec;
  const byId = new Map(products.map(product => [product[0], product]));
  const items = lines.map(([productId, quantity]) => {
    const [, name, , price, , unit, image] = byId.get(productId);
    return {
      productId, productName: name, quantity, unitPriceMinor: price,
      lineTotalMinor: price * quantity, currencyCode: 'LKR',
      imageUrl: `assets/images/${image}`, unit,
    };
  });
  const total = items.reduce((sum, item) => sum + item.lineTotalMinor, 0);
  const steps = ['placed', 'accepted', 'preparing', 'ready'];
  const reached = step => steps.indexOf(status) >= steps.indexOf(step);
  const customer = ACCOUNTS.find(account => account.key === 'customer');
  const order = {
    id, customerId: uids.customer, shopId: uids.shop, shopName: SHOP_NAME,
    customerName: customer.fullName, customerPhone: customer.phone,
    items, subtotalMinor: total, totalMinor: total, currencyCode: 'LKR',
    paymentMethod: method, paymentStatus: method === 'cashOnPickup' ? 'unpaid' : 'demo',
    status, pickupAt: Timestamp.fromMillis(Date.now() + hours * 3600000),
    replacementPreference: 'allowReplacement',
    stockReserved: true, stockRestored: false,
    stockQuantities: Object.fromEntries(lines),
    createdAt: now, updatedAt: now,
    acceptedAt: reached('accepted') ? now : null,
    preparingAt: reached('preparing') ? now : null,
    readyAt: reached('ready') ? now : null,
    collectedAt: null, cancelledAt: null, completedAt: null,
  };
  const payment = {
    id, orderId: id, customerId: uids.customer, shopId: uids.shop, method,
    provider, cardLast4, amountMinor: total, currencyCode: 'LKR',
    status: method === 'cashOnPickup' ? 'pending' : 'demo_paid',
    reference: `DEMO-${id.replace(/[^A-Za-z0-9]/g, '').slice(0, 8).toUpperCase()}`,
    isDemo: true, createdAt: now,
  };
  return { order, payment };
}

// Dependencies are injected so the plan can be checked offline.
async function seed({ auth, db, FieldValue, Timestamp, password }) {
  validatePassword(password);
  const now = FieldValue.serverTimestamp();
  const uids = {};
  const report = [];
  for (const account of ACCOUNTS) {
    const { user, created } = await ensureAccount(auth, account, password);
    uids[account.key] = user.uid;
    report.push(`${account.role.padEnd(8)} ${account.email} (${created ? 'created' : 'existing, password unchanged'})`);
  }

  const batch = db.batch();
  for (const account of ACCOUNTS) {
    batch.set(db.collection('users').doc(uids[account.key]),
      profileFor(account, uids[account.key], now), { merge: true });
  }
  for (const product of PRODUCTS) {
    batch.set(db.collection('products').doc(product[0]), productDoc(product, uids.shop, now));
  }
  for (const spec of ORDERS) {
    const { order, payment } = orderDocs(spec, uids, PRODUCTS, { now, Timestamp });
    batch.set(db.collection('orders').doc(order.id), order);
    batch.set(db.collection('payments').doc(order.id), payment);
  }
  const placed = db.collection('orders').doc('demo-order-placed');
  batch.set(placed.collection('messages').doc('demo-message-1'), {
    id: 'demo-message-1', senderId: uids.customer, senderRole: 'customer',
    text: 'Hi! Could you pick the ripest apples, please?', createdAt: now,
  });
  batch.set(db.collection('notifications').doc('demo-order-ready_ORDER_READY'), {
    id: 'demo-order-ready_ORDER_READY', userId: uids.customer, type: 'ORDER_READY',
    title: 'Order Ready!', message: '#demo-order-ready is ready for pickup.',
    orderId: 'demo-order-ready', productId: null, createdAt: now, isRead: false,
  });
  await batch.commit();
  report.push(`${PRODUCTS.length} products, ${ORDERS.length} orders with demo receipts, 1 message, 1 notification`);
  return report;
}

async function readPassword(env = process.env) {
  if (env.PIKZEN_DEMO_PASSWORD !== undefined) return env.PIKZEN_DEMO_PASSWORD;
  if (!process.stdin.isTTY) {
    throw new SeedError('Run in an interactive terminal or set PIKZEN_DEMO_PASSWORD.');
  }
  let muted = false;
  const output = new Writable({
    write(chunk, encoding, done) { if (!muted) process.stdout.write(chunk, encoding); done(); },
  });
  const rl = readline.createInterface({ input: process.stdin, output, terminal: true, historySize: 0 });
  process.stdout.write('Password for NEW demo accounts (hidden, min 8 chars): ');
  muted = true;
  try {
    return await new Promise(resolve => rl.question('', resolve));
  } finally {
    muted = false;
    process.stdout.write('\n');
    rl.close();
  }
}

async function main() {
  let app;
  try {
    if (process.argv.length > 2) throw new SeedError('This script takes no command-line arguments.');
    const projectId = process.env.GOOGLE_CLOUD_PROJECT?.trim();
    if (!projectId) throw new SeedError('Set GOOGLE_CLOUD_PROJECT to the Firebase project to seed.');
    const emulated = Boolean(process.env.FIRESTORE_EMULATOR_HOST);
    if (emulated !== Boolean(process.env.FIREBASE_AUTH_EMULATOR_HOST)) {
      throw new SeedError('Set both FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST, or neither.');
    }
    const password = validatePassword(await readPassword());
    delete process.env.PIKZEN_DEMO_PASSWORD;
    const sdk = require('firebase-admin/app');
    const { getFirestore, FieldValue, Timestamp } = require('firebase-admin/firestore');
    app = sdk.initializeApp(emulated ? { projectId } : { credential: sdk.applicationDefault(), projectId });
    const report = await seed({
      auth: require('firebase-admin/auth').getAuth(app),
      db: getFirestore(app), FieldValue, Timestamp, password,
    });
    console.log([`Seeded ${emulated ? 'emulator' : 'project'} ${projectId}:`, ...report.map(line => `  ${line}`)].join('\n'));
  } catch (error) {
    console.error(error instanceof SeedError ? error.message
      : 'Seeding failed. Check credentials, project ID and that Auth/Firestore are enabled.');
    process.exitCode = 1;
  } finally {
    if (app) await require('firebase-admin/app').deleteApp(app).catch(() => {});
  }
}

if (require.main === module) void main();
module.exports = { seed, orderDocs, ACCOUNTS, PRODUCTS, ORDERS, SeedError };
