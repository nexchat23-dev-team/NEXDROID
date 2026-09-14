import express from 'express';
import * as marketplaceController from '../controllers/marketplaceController.js';
import { authenticate } from '../middleware/auth.js';
import { validateBody } from '../middleware/validator.js';

const router = express.Router();

router.use(authenticate);

// GET /listings - Browse listings (paginated, filtered)
router.get('/listings', marketplaceController.browseListings);

// POST /listings - Create listing
router.post('/listings', validateBody, marketplaceController.createListing);

// GET /listings/:id - Get listing details
router.get('/listings/:id', marketplaceController.getListing);

// PUT /listings/:id - Update listing
router.put('/listings/:id', validateBody, marketplaceController.updateListing);

// DELETE /listings/:id - Remove listing
router.delete('/listings/:id', marketplaceController.removeListing);

// POST /listings/:id/offer - Make offer
router.post('/listings/:id/offer', validateBody, marketplaceController.makeOffer);

// GET /offers - Get user's offers
router.get('/offers', marketplaceController.getUserOffers);

// PUT /offers/:offerId - Respond to offer
router.put('/offers/:offerId', validateBody, marketplaceController.respondToOffer);

export default router;
