import { auth, db } from '../config/firebase.js';

/**
 * Middleware to authenticate requests using Firebase ID tokens.
 */
export const authenticate = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({
        status: 'fail',
        message: 'Unauthorized: Missing or invalid Authorization header'
      });
    }

    const token = authHeader.split('Bearer ')[1];
    
    // Verify the token
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(token);
    } catch (fbError) {
      // Fallback to custom JWT
      try {
        const jwt = await import('jsonwebtoken');
        decodedToken = jwt.default.verify(token, process.env.JWT_SECRET || 'default-secret-key-change-me');
      } catch (jwtError) {
        throw new Error('Invalid or expired token');
      }
    }
    
    // Attach user to request
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified,
      role: decodedToken.role, // custom JWT role
      username: decodedToken.username,
    };
    
    next();
  } catch (error) {
    return res.status(401).json({
      status: 'fail',
      message: 'Unauthorized: Invalid or expired token',
      error: error.message
    });
  }
};

/**
 * Middleware for optional authentication. Sets req.user if token is valid, otherwise null.
 */
export const optionalAuth = async (req, res, next) => {
  try {
    const authHeader = req.headers.authorization;
    
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      req.user = null;
      return next();
    }

    const token = authHeader.split('Bearer ')[1];
    let decodedToken;
    try {
      decodedToken = await auth.verifyIdToken(token);
    } catch (fbError) {
      const jwt = await import('jsonwebtoken');
      decodedToken = jwt.default.verify(token, process.env.JWT_SECRET || 'default-secret-key-change-me');
    }
    
    req.user = {
      uid: decodedToken.uid,
      email: decodedToken.email,
      emailVerified: decodedToken.email_verified,
      role: decodedToken.role,
      username: decodedToken.username,
    };
    
    next();
  } catch (error) {
    req.user = null;
    next();
  }
};

/**
 * Helper function to check user roles in Firestore
 */
const checkRole = (allowedRoles) => async (req, res, next) => {
  try {
    if (!req.user) {
      return res.status(401).json({
        status: 'fail',
        message: 'Unauthorized: Authentication required'
      });
    }

    const superAdminEmail = 'demonalexander526@gmail.com';
    
    // Super admin bypass
    if (req.user.email === superAdminEmail && allowedRoles.includes('admin')) {
      return next();
    }
    
    // Custom JWT superadmin bypass
    if (req.user.role === 'superadmin' && req.user.uid === 'nex-superadmin') {
      return next();
    }

    // Fetch user doc from Firestore
    const userDoc = await db.collection('users').doc(req.user.uid).get();
    
    if (!userDoc.exists) {
      return res.status(403).json({
        status: 'fail',
        message: 'Forbidden: User record not found'
      });
    }

    const userData = userDoc.data();
    const userRole = userData.role;

    if (allowedRoles.includes(userRole) || (userRole === 'admin')) {
      return next();
    }

    return res.status(403).json({
      status: 'fail',
      message: 'Forbidden: Insufficient permissions'
    });
  } catch (error) {
    return res.status(500).json({
      status: 'error',
      message: 'Internal server error during role verification',
      error: error.message
    });
  }
};

/**
 * Middleware to require admin privileges
 */
export const requireAdmin = checkRole(['admin']);

/**
 * Middleware to require moderator or admin privileges
 */
export const requireModerator = checkRole(['moderator', 'admin']);
