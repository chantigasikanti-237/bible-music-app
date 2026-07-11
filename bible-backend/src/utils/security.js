const {
  createHash,
  randomBytes,
  randomInt,
  randomUUID,
  timingSafeEqual,
} = require("crypto");

const hashToBuffer = (value) =>
  createHash("sha256").update(String(value || ""), "utf8").digest();

const hashValue = (value) => hashToBuffer(value).toString("hex");

const compareHashedValue = (value, storedHash) => {
  if (!storedHash) {
    return false;
  }

  const candidateBuffer = hashToBuffer(value);
  const storedBuffer = Buffer.from(String(storedHash), "hex");

  if (candidateBuffer.length !== storedBuffer.length) {
    return false;
  }

  return timingSafeEqual(candidateBuffer, storedBuffer);
};

const createOpaqueSessionToken = () => {
  const sessionId = randomUUID();
  const sessionSecret = randomBytes(48).toString("base64url");

  return {
    sessionId,
    refreshToken: `${sessionId}.${sessionSecret}`,
    refreshTokenHash: hashValue(sessionSecret),
  };
};

const parseOpaqueSessionToken = (token) => {
  const normalizedToken = String(token || "").trim();
  const [sessionId, sessionSecret] = normalizedToken.split(".");

  if (!sessionId || !sessionSecret) {
    return null;
  }

  return {
    sessionId,
    sessionSecret,
  };
};

const createPasswordResetToken = (ttlMs) => {
  const token = randomBytes(32).toString("base64url");

  return {
    token,
    tokenHash: hashValue(token),
    expiresAt: new Date(Date.now() + ttlMs),
  };
};

const createPasswordResetOtp = (ttlMs) => {
  const otp = String(randomInt(0, 1000000)).padStart(6, "0");

  return {
    otp,
    tokenHash: hashValue(otp),
    expiresAt: new Date(Date.now() + ttlMs),
  };
};

const createEmailVerificationOtp = (ttlMs) => {
  const otp = String(randomInt(0, 1000000)).padStart(6, "0");

  return {
    otp,
    tokenHash: hashValue(otp),
    expiresAt: new Date(Date.now() + ttlMs),
  };
};

module.exports = {
  hashValue,
  compareHashedValue,
  createOpaqueSessionToken,
  parseOpaqueSessionToken,
  createPasswordResetToken,
  createPasswordResetOtp,
  createEmailVerificationOtp,
};
