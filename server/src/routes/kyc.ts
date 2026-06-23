import { Router } from "express";
import { z } from "zod";
import { requireAuth, type AuthedRequest } from "../middleware/auth.js";
import { admin, audit } from "../supabase.js";
import { kycProvider } from "../providers/kyc.js";

export const kycRouter = Router();
const provider = kycProvider();

// Start Aadhaar OTP eKYC. The full Aadhaar is used transiently and never stored.
kycRouter.post("/aadhaar/initiate", requireAuth, async (req: AuthedRequest, res) => {
  const body = z.object({ aadhaar: z.string().regex(/^\d{12}$/) }).safeParse(req.body);
  if (!body.success) return res.status(400).json({ error: "invalid aadhaar" });
  const { refId } = await provider.initiateAadhaar(body.data.aadhaar);
  await audit(req.userId!, "kyc.aadhaar.initiate", "users", req.userId!, {}, req.ip);
  res.json({ refId });
});

// Complete eKYC; store ONLY last4 + provider token, then mark verified.
kycRouter.post("/aadhaar/verify", requireAuth, async (req: AuthedRequest, res) => {
  const body = z
    .object({ refId: z.string(), otp: z.string().regex(/^\d{6}$/), role: z.enum(["farmer", "dealer"]) })
    .safeParse(req.body);
  if (!body.success) return res.status(400).json({ error: "invalid input" });

  const result = await provider.verifyAadhaarOtp(body.data.refId, body.data.otp);
  if (!result.verified) return res.status(400).json({ error: "verification failed" });

  const table = body.data.role === "farmer" ? "farmer_profiles" : "dealer_profiles";
  await admin.from(table).upsert({
    user_id: req.userId!,
    aadhaar_last4: result.last4,
    aadhaar_ref_token: result.token,
    aadhaar_verified: true,
    consent_at: new Date().toISOString(),
  });
  await admin.from("users").update({ kyc_status: "verified" }).eq("id", req.userId!);
  await audit(req.userId!, "kyc.aadhaar.verify", "users", req.userId!, { last4: result.last4 }, req.ip);
  res.json({ verified: true });
});

kycRouter.post("/gst", requireAuth, async (req: AuthedRequest, res) => {
  const body = z.object({ gst: z.string().regex(/^[0-9A-Z]{15}$/) }).safeParse(req.body);
  if (!body.success) return res.status(400).json({ error: "invalid gst" });
  const r = await provider.verifyGst(body.data.gst);
  if (!r.verified) return res.status(400).json({ error: "gst not verified" });
  await admin.from("dealer_profiles").upsert({
    user_id: req.userId!,
    gst_number: body.data.gst,
    gst_verified: true,
  });
  await audit(req.userId!, "kyc.gst.verify", "users", req.userId!, {}, req.ip);
  res.json({ verified: true, legalName: r.legalName });
});
