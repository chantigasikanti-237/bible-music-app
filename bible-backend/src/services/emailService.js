const nodemailer = require("nodemailer");

const { config } = require("../config/env");
const AppError = require("../utils/AppError");
const logger = require("../config/logger");

const createEmailService = ({ mailerFactory = nodemailer.createTransport } = {}) => {
  const isConfigured = () =>
    Boolean(
      config.smtpHost &&
        config.smtpPort &&
        config.smtpUser &&
        config.smtpPass &&
        config.smtpFrom
    );

  let cachedTransport = null;

  // Reuses a pooled connection instead of doing a fresh TCP+TLS+AUTH
  // handshake with the SMTP server on every single email (that handshake
  // alone is where most of the multi-second send time was going).
  const getTransport = () => {
    if (!cachedTransport) {
      cachedTransport = mailerFactory({
        host: config.smtpHost,
        port: config.smtpPort,
        secure: config.smtpSecure,
        auth: {
          user: config.smtpUser,
          pass: config.smtpPass,
        },
        pool: true,
        maxConnections: 5,
        maxMessages: 100,
      });
    }

    return cachedTransport;
  };

  return {
    isConfigured,

    assertConfigured() {
      if (!isConfigured()) {
        throw new AppError(
          503,
          "Password reset email is not configured. Please contact support."
        );
      }
    },

    async sendEmailVerificationOtp({ to, otp, expiresInMinutes }) {
      this.assertConfigured();

      try {
        const transporter = getTransport();
        await transporter.sendMail({
          from: config.smtpFrom,
          to,
          subject: "Verify your Bible App email",
          text: [
            "Use this one-time code to verify your Bible App email address:",
            "",
            otp,
            "",
            `This code expires in ${expiresInMinutes} minutes.`,
            "If you did not create this account, you can ignore this email.",
          ].join("\n"),
          html: [
            "<p>Use this one-time code to verify your Bible App email address:</p>",
            `<p style=\"font-size:24px;font-weight:700;letter-spacing:4px;\">${otp}</p>`,
            `<p>This code expires in ${expiresInMinutes} minutes.</p>`,
            "<p>If you did not create this account, you can ignore this email.</p>",
          ].join(""),
        });
      } catch (error) {
        logger.error("Failed to send email verification email", {
          error: error.message,
          to,
        });
        throw new AppError(
          502,
          "Could not send verification email. Please try again later."
        );
      }
    },

    async sendPasswordResetOtp({ to, otp, expiresInMinutes }) {
      this.assertConfigured();

      try {
        const transporter = getTransport();
        await transporter.sendMail({
          from: config.smtpFrom,
          to,
          subject: "Your Bible App password reset code",
          text: [
            "Use this one-time code to reset your Bible App password:",
            "",
            otp,
            "",
            `This code expires in ${expiresInMinutes} minutes.`,
            "If you did not request this, you can ignore this email.",
          ].join("\n"),
          html: [
            "<p>Use this one-time code to reset your Bible App password:</p>",
            `<p style=\"font-size:24px;font-weight:700;letter-spacing:4px;\">${otp}</p>`,
            `<p>This code expires in ${expiresInMinutes} minutes.</p>`,
            "<p>If you did not request this, you can ignore this email.</p>",
          ].join(""),
        });
      } catch (error) {
        logger.error("Failed to send password reset email", {
          error: error.message,
          to,
        });
        throw new AppError(
          502,
          "Could not send password reset email. Please try again later."
        );
      }
    },
  };
};

module.exports = {
  createEmailService,
  emailService: createEmailService(),
};
