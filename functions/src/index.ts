import { initializeApp } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';
import { cancelOrderCore, placeOrderCore, rejectShopOrderCore } from './orders';

initializeApp();
const db = getFirestore();
const options = { region: 'asia-south1' } as const;

export const placeOrder = onCall(options, async (request) =>
  placeOrderCore(db, request.auth?.uid, request.data));

export const cancelOrder = onCall(options, async (request) =>
  cancelOrderCore(db, request.auth?.uid, request.data));

export const rejectShopOrder = onCall(options, async (request) =>
  rejectShopOrderCore(db, request.auth?.uid, request.data));
