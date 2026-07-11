const { z } = require("zod");

const AppError = require("./AppError");

const normalizeEmail = (value) => String(value || "").trim().toLowerCase();
const normalizeOptionalString = (value) => {
  if (value === undefined || value === null) {
    return undefined;
  }

  const normalized = String(value).trim();
  return normalized || undefined;
};

const passwordSchema = z
  .string()
  .min(10, "Password must be at least 10 characters long")
  .max(128, "Password must be at most 128 characters long")
  .refine((value) => /[A-Z]/.test(value), {
    message: "Password must include at least one uppercase letter",
  })
  .refine((value) => /[^A-Za-z0-9]/.test(value), {
    message: "Password must include at least one special character",
  });

const emailSchema = z.string().email("A valid email address is required");

const signupSchema = z
  .object({
    email: emailSchema.transform(normalizeEmail),
    password: passwordSchema,
    name: z
      .string()
      .trim()
      .min(1, "Name cannot be empty")
      .max(100, "Name cannot exceed 100 characters")
      .optional(),
  })
  .strict();

const loginSchema = z
  .object({
    email: emailSchema.transform(normalizeEmail),
    password: z
      .string()
      .min(1, "Password is required")
      .max(128, "Password must be at most 128 characters long"),
  })
  .strict();

const refreshSchema = z
  .object({
    refreshToken: z.string().trim().min(1, "Refresh token is required"),
  })
  .strict();

const passwordResetRequestSchema = z
  .object({
    email: emailSchema.transform(normalizeEmail),
  })
  .strict();

const passwordResetSchema = z
  .object({
    otpCode: z
      .string()
      .trim()
      .regex(/^\d{6}$/, "Password reset code must be 6 digits"),
    password: passwordSchema,
    confirmPassword: z.string().trim().min(1, "Confirm password is required"),
  })
  .strict()
  .superRefine((value, ctx) => {
    if (value.password !== value.confirmPassword) {
      ctx.addIssue({
        code: "custom",
        message: "Passwords do not match",
        path: ["confirmPassword"],
      });
    }
  });

const emailVerificationResendSchema = z
  .object({
    email: emailSchema.transform(normalizeEmail),
  })
  .strict();

const emailVerificationConfirmSchema = z
  .object({
    otpCode: z
      .string()
      .trim()
      .regex(/^\d{6}$/, "Verification code must be 6 digits"),
  })
  .strict();

const optionalRefreshBodySchema = z
  .object({
    refreshToken: z
      .string()
      .trim()
      .min(1, "Refresh token is required")
      .optional(),
  })
  .strict()
  .transform((value) => ({
    refreshToken: normalizeOptionalString(value.refreshToken),
  }));

const formatZodError = (error) =>
  error.issues.map((issue) => ({
    field: issue.path.join(".") || "body",
    message: issue.message,
  }));

const validateWithSchema = (schema, payload) => {
  const result = schema.safeParse(payload);

  if (!result.success) {
    const errors = formatZodError(result.error);
    throw new AppError(400, errors[0]?.message || "Validation failed", {
      errors,
    });
  }

  return result.data;
};

module.exports = {
  signupSchema,
  loginSchema,
  refreshSchema,
  passwordResetRequestSchema,
  passwordResetSchema,
  emailVerificationResendSchema,
  emailVerificationConfirmSchema,
  optionalRefreshBodySchema,
  validateWithSchema,
};
