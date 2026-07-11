const { randomUUID } = require("crypto");

const requestContext = (req, res, next) => {
  const requestId = req.headers["x-request-id"] || randomUUID();
  req.requestId = requestId;
  req.requestStartAt = Date.now();
  res.setHeader("x-request-id", requestId);
  next();
};

module.exports = requestContext;
