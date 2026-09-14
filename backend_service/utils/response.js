/**
 * Standardized success response
 */
export const success = (res, data = null, message = 'Success', statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data
  });
};

/**
 * Standardized error response
 */
export const error = (res, message = 'Internal Server Error', statusCode = 500, details = null) => {
  const response = {
    success: false,
    message
  };
  
  if (details) {
    response.details = details;
  }
  
  return res.status(statusCode).json(response);
};

/**
 * Standardized paginated response
 */
export const paginated = (res, data, page, limit, total, message = 'Success', statusCode = 200) => {
  return res.status(statusCode).json({
    success: true,
    message,
    data,
    meta: {
      page: parseInt(page, 10),
      limit: parseInt(limit, 10),
      total,
      totalPages: Math.ceil(total / limit)
    }
  });
};
