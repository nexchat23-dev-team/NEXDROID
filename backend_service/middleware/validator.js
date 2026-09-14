/**
 * Lightweight request validation middleware.
 */

// Basic email regex
const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
// Basic URL regex
const urlRegex = /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/;
// UUID regex
const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i;

const validateValue = (value, rules, key) => {
  if (rules.required && (value === undefined || value === null || value === '')) {
    return `${key} is required.`;
  }

  if (value === undefined || value === null || value === '') {
    return null; // Skip further validation if optional and not provided
  }

  if (rules.type) {
    if (rules.type === 'array' && !Array.isArray(value)) {
      return `${key} must be an array.`;
    } else if (rules.type === 'object' && (typeof value !== 'object' || Array.isArray(value))) {
      return `${key} must be an object.`;
    } else if (rules.type !== 'array' && rules.type !== 'object' && typeof value !== rules.type) {
      return `${key} must be of type ${rules.type}.`;
    }
  }

  if (rules.type === 'string') {
    if (rules.minLength && value.length < rules.minLength) {
      return `${key} must be at least ${rules.minLength} characters long.`;
    }
    if (rules.maxLength && value.length > rules.maxLength) {
      return `${key} must be at most ${rules.maxLength} characters long.`;
    }
    if (rules.pattern) {
      if (rules.pattern === 'email' && !emailRegex.test(value)) {
        return `${key} must be a valid email address.`;
      }
      if (rules.pattern === 'url' && !urlRegex.test(value)) {
        return `${key} must be a valid URL.`;
      }
      if (rules.pattern === 'uuid' && !uuidRegex.test(value)) {
        return `${key} must be a valid UUID.`;
      }
    }
  }

  if (rules.type === 'number') {
    if (rules.min !== undefined && value < rules.min) {
      return `${key} must be at least ${rules.min}.`;
    }
    if (rules.max !== undefined && value > rules.max) {
      return `${key} must be at most ${rules.max}.`;
    }
  }

  if (rules.enum && Array.isArray(rules.enum)) {
    if (!rules.enum.includes(value)) {
      return `${key} must be one of: ${rules.enum.join(', ')}.`;
    }
  }

  return null;
};

const createValidator = (target) => (schema) => (req, res, next) => {
  const data = req[target] || {};
  const errors = [];

  for (const [key, rules] of Object.entries(schema)) {
    const error = validateValue(data[key], rules, key);
    if (error) {
      errors.push({ field: key, message: error });
    }
  }

  if (errors.length > 0) {
    return res.status(400).json({
      status: 'fail',
      message: 'Validation failed',
      errors
    });
  }

  next();
};

export const validateBody = createValidator('body');
export const validateParams = createValidator('params');
export const validateQuery = createValidator('query');
