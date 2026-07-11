const AppError = require("./AppError");

const isValueMissing = (value) => {
  if (value === undefined || value === null) {
    return true;
  }

  if (typeof value === "string" && value.trim() === "") {
    return true;
  }

  return false;
};

const validateRequiredFields = (payload, requiredFields) => {
  const normalizedPayload = payload || {};

  const missingFields = requiredFields.filter((field) =>
    isValueMissing(normalizedPayload[field])
  );

  if (missingFields.length > 0) {
    throw new AppError(400, "Validation failed", {
      missingFields,
    });
  }
};

const parsePositiveInteger = (value, fieldName) => {
  const parsedValue = Number(value);

  if (!Number.isInteger(parsedValue) || parsedValue <= 0) {
    throw new AppError(400, `${fieldName} must be a positive integer`);
  }

  return parsedValue;
};

module.exports = {
  validateRequiredFields,
  parsePositiveInteger,
};
