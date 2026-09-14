import { db } from '../config/firebase.js';
import { AppError, catchAsync } from '../middleware/errorHandler.js';
import { success, paginated } from '../utils/response.js';
import logger from '../utils/logger.js';
import { FieldValue } from 'firebase-admin/firestore';

export const listListings = catchAsync(async (req, res) => {
  const page = parseInt(req.query.page) || 1;
  const limit = parseInt(req.query.limit) || 10;
  let query = db.collection('marketplaceListings').orderBy('createdAt', 'desc');

  if (req.query.category) query = query.where('category', '==', req.query.category);

  const snapshot = await query.offset((page - 1) * limit).limit(limit).get();
  const listings = snapshot.docs.map(doc => ({ id: doc.id, ...doc.data() }));
  return paginated(res, 200, listings, page, limit);
});

export const browseListings = listListings;

export const createListing = catchAsync(async (req, res) => {
  const { title, description, price, category, images } = req.body;
  const data = {
    title, description, price, category, images,
    sellerId: req.user.uid,
    status: 'active',
    createdAt: FieldValue.serverTimestamp()
  };

  const docRef = await db.collection('marketplaceListings').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getListing = catchAsync(async (req, res) => {
  const listingId = req.params.id || req.params.listingId;
  const doc = await db.collection('marketplaceListings').doc(listingId).get();
  if (!doc.exists) throw new AppError('Listing not found', 404);
  return success(res, 200, { id: doc.id, ...doc.data() });
});

export const updateListing = catchAsync(async (req, res) => {
  const listingId = req.params.id || req.params.listingId;
  const docRef = db.collection('marketplaceListings').doc(listingId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().sellerId !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.update({ ...req.body, updatedAt: FieldValue.serverTimestamp() });
  return success(res, 200, null, 'Listing updated');
});

export const deleteListing = catchAsync(async (req, res) => {
  const listingId = req.params.id || req.params.listingId;
  const docRef = db.collection('marketplaceListings').doc(listingId);
  const doc = await docRef.get();
  if (!doc.exists || doc.data().sellerId !== req.user.uid) throw new AppError('Forbidden', 403);

  await docRef.delete();
  return success(res, 200, null, 'Listing deleted');
});

export const removeListing = deleteListing;

export const makeOffer = catchAsync(async (req, res) => {
  const { amount, message } = req.body;
  const listingId = req.params.id || req.params.listingId;
  const data = {
    buyerId: req.user.uid,
    listingId,
    amount, message,
    status: 'pending',
    createdAt: FieldValue.serverTimestamp()
  };
  const docRef = await db.collection('marketplaceOffers').add(data);
  return success(res, 201, { id: docRef.id, ...data });
});

export const getOffers = catchAsync(async (req, res) => {
  const buyerOffers = await db.collection('marketplaceOffers').where('buyerId', '==', req.user.uid).get();
  const sellerOffers = await db.collection('marketplaceOffers').where('sellerId', '==', req.user.uid).get();
  
  const offers = [
    ...buyerOffers.docs.map(doc => ({ id: doc.id, ...doc.data(), role: 'buyer' })),
    ...sellerOffers.docs.map(doc => ({ id: doc.id, ...doc.data(), role: 'seller' }))
  ];
  return success(res, 200, offers);
});

export const getUserOffers = getOffers;

export const respondToOffer = catchAsync(async (req, res) => {
  const { action } = req.body; // accept, reject
  const offerId = req.params.offerId || req.params.id;
  const docRef = db.collection('marketplaceOffers').doc(offerId);
  await docRef.update({ status: action === 'accept' ? 'accepted' : 'rejected' });
  
  if (action === 'accept') {
    const offerDoc = await docRef.get();
    await db.collection('marketplaceListings').doc(offerDoc.data().listingId).update({ status: 'sold' });
  }

  return success(res, 200, null, `Offer ${action}ed`);
});

// Official Token Conversion: 10,000 Tokens = $1.00 USD
export const getTokenPackages = catchAsync(async (req, res) => {
  const packages = [
    { id: 'starter', tokens: 10000, priceUsd: 1.00, label: 'Starter Deck' },
    { id: 'operative', tokens: 50000, priceUsd: 5.00, label: 'Operative Cache' },
    { id: 'vanguard', tokens: 100000, priceUsd: 10.00, label: 'Vanguard Vault' },
    { id: 'cyber_lord', tokens: 250000, priceUsd: 25.00, label: 'Cyber Lord Arsenal' },
    { id: 'singularity', tokens: 1000000, priceUsd: 100.00, label: 'Singularity Overload' },
  ];
  return success(res, 200, packages);
});

export default {
  listListings, browseListings, createListing, getListing, updateListing,
  deleteListing, removeListing, makeOffer, getOffers, getUserOffers,
  respondToOffer, getTokenPackages
};
