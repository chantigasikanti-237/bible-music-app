const asyncHandler = require("../utils/asyncHandler");
const { authService } = require("../services/authService");
const {
  setRefreshTokenCookie,
  clearRefreshTokenCookie,
} = require("../utils/cookies");
const {
  getRequestIp,
  getRequestUserAgent,
  getRefreshTokenFromRequest,
} = require("../utils/http");

const buildRequestContext = (req) => ({
  ipAddress: getRequestIp(req),
  userAgent: getRequestUserAgent(req),
  requestId: req.requestId || null,
});

const register = asyncHandler(async (req, res) => {
  const result = await authService.registerUser(req.body);

  res.status(201).json({
    success: true,
    message: "User created successfully",
    ...result,
  });
});

const login = asyncHandler(async (req, res) => {
  const result = await authService.loginUser(req.body, buildRequestContext(req));

  // Access tokens stay short-lived and live in the Authorization header.
  // The longer-lived refresh secret is rotated server-side and sent as an
  // HttpOnly cookie so browser JavaScript cannot read it.
  setRefreshTokenCookie(res, result.refreshToken);

  res.status(200).json({
    success: true,
    message: "Login successful",
    token: result.accessToken,
    accessToken: result.accessToken,
    session: result.session,
    user: result.user,
  });
});

const refresh = asyncHandler(async (req, res) => {
  const result = await authService.refreshSession(
    getRefreshTokenFromRequest(req),
    buildRequestContext(req)
  );

  setRefreshTokenCookie(res, result.refreshToken);

  res.status(200).json({
    success: true,
    message: "Session refreshed successfully",
    token: result.accessToken,
    accessToken: result.accessToken,
    session: result.session,
    user: result.user,
  });
});

const logout = asyncHandler(async (req, res) => {
  await authService.logoutUser({
    sessionId: req.auth?.sessionId,
    userId: req.user?._id || req.user?.id || null,
  });

  clearRefreshTokenCookie(res);

  res.status(200).json({
    success: true,
    message: "Logged out successfully",
  });
});

const requestPasswordReset = asyncHandler(async (req, res) => {
  const result = await authService.requestPasswordReset(req.body);

  res.status(200).json({
    success: true,
    ...result,
  });
});

const resetPassword = asyncHandler(async (req, res) => {
  const result = await authService.resetPassword(req.body);

  clearRefreshTokenCookie(res);

  res.status(200).json({
    success: true,
    message: "Password reset successful",
    user: result.user,
  });
});

const resendVerificationEmail = asyncHandler(async (req, res) => {
  const result = await authService.resendVerificationEmail(req.body);

  res.status(200).json({
    success: true,
    ...result,
  });
});

const verifyEmail = asyncHandler(async (req, res) => {
  const result = await authService.verifyEmail(req.body);

  res.status(200).json({
    success: true,
    message: "Email verified successfully",
    user: result.user,
  });
});

module.exports = {
  register,
  login,
  refresh,
  logout,
  requestPasswordReset,
  resetPassword,
  resendVerificationEmail,
  verifyEmail,
};
