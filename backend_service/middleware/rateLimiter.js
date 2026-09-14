import rateLimit from 'express-rate-limit';

const createRateLimiter = (windowMs, max, message) => {
  return rateLimit({
    windowMs,
    max,
    standardHeaders: true, // Return rate limit info in the `RateLimit-*` headers
    legacyHeaders: false, // Disable the `X-RateLimit-*` headers
    handler: (req, res) => {
      res.status(429).json({
        status: 'fail',
        message: message || 'Too many requests, please try again later.'
      });
    }
  });
};

// Global limit: 100 requests per 15 minutes per IP
export const globalLimiter = createRateLimiter(
  15 * 60 * 1000, 
  100,
  'Too many requests from this IP, please try again after 15 minutes.'
);

// Auth endpoints: 20 requests per 15 minutes
export const authLimiter = createRateLimiter(
  15 * 60 * 1000,
  20,
  'Too many authentication attempts, please try again after 15 minutes.'
);

// Upload endpoints: 10 requests per hour
export const uploadLimiter = createRateLimiter(
  60 * 60 * 1000,
  10,
  'Too many upload attempts, please try again after an hour.'
);

// API limit: 60 requests per minute
export const apiLimiter = createRateLimiter(
  60 * 1000,
  60,
  'API rate limit exceeded, please try again after a minute.'
);
