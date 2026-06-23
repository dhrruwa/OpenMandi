import { env } from "../env.js";

// COMPLIANCE: never call UIDAI directly and never store the full Aadhaar.
// This abstracts a UIDAI-licensed provider (Setu / Cashfree / Sandbox.co.in /
// Signzy / IDfy / Digio). The sandbox impl simulates the OTP-eKYC handshake so
// the flow is exercised end-to-end without real PII. Swap in a real adapter by
// implementing this interface against the provider's API.

export interface KycProvider {
  /** Start Aadhaar OTP eKYC. Returns a provider reference; sends OTP to the
   *  Aadhaar-linked phone. The full number is passed transiently, never stored. */
  initiateAadhaar(aadhaar: string): Promise<{ refId: string }>;
  /** Complete eKYC with the OTP. Returns only safe artifacts. */
  verifyAadhaarOtp(
    refId: string,
    otp: string,
  ): Promise<{ verified: boolean; last4: string; token: string }>;
  /** GST verification for dealers. */
  verifyGst(gst: string): Promise<{ verified: boolean; legalName?: string }>;
}

class SandboxKyc implements KycProvider {
  async initiateAadhaar(aadhaar: string) {
    if (!/^\d{12}$/.test(aadhaar)) throw new Error("invalid aadhaar format");
    return { refId: `sbx_${Date.now().toString(36)}` };
  }
  async verifyAadhaarOtp(refId: string, otp: string) {
    // sandbox: any 6-digit OTP passes; we only return last4 + an opaque token
    const verified = /^\d{6}$/.test(otp);
    return { verified, last4: "0000", token: `tok_${refId}` };
  }
  async verifyGst(gst: string) {
    const verified = /^[0-9A-Z]{15}$/.test(gst);
    return { verified, legalName: verified ? "Verified Business (sandbox)" : undefined };
  }
}

// TODO: implement a real provider adapter (e.g. SetuKyc) using env.KYC_API_*.
export function kycProvider(): KycProvider {
  switch (env.KYC_PROVIDER) {
    case "sandbox":
    default:
      return new SandboxKyc();
  }
}
