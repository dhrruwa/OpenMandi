import { z } from "zod";

// Fail fast on misconfiguration; secrets never have defaults.
const schema = z.object({
  PORT: z.coerce.number().default(8787),
  NODE_ENV: z.enum(["development", "production", "test"]).default("development"),
  SUPABASE_URL: z.string().url(),
  SUPABASE_SERVICE_ROLE_KEY: z.string().min(20),
  SUPABASE_JWT_AUD: z.string().default("authenticated"),
  CORS_ORIGINS: z.string().default(""),
  DATA_ENC_KEY: z.string().optional(),
  RAZORPAY_KEY_ID: z.string().optional(),
  RAZORPAY_KEY_SECRET: z.string().optional(),
  RAZORPAY_WEBHOOK_SECRET: z.string().optional(),
  KYC_PROVIDER: z.string().default("sandbox"),
  KYC_API_BASE: z.string().optional(),
  KYC_API_KEY: z.string().optional(),
  KYC_API_SECRET: z.string().optional(),
  DATAGOV_API_KEY: z.string().optional(),
});

export const env = schema.parse(process.env);

export const corsOrigins = env.CORS_ORIGINS.split(",")
  .map((s) => s.trim())
  .filter(Boolean);
