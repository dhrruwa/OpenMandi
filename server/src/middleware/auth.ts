import type { NextFunction, Request, Response } from "express";
import { admin } from "../supabase.js";

export interface AuthedRequest extends Request {
  userId?: string;
}

// Verify the caller's Supabase access token (Bearer JWT). We resolve it via
// the Auth API so revoked/expired tokens are rejected.
export async function requireAuth(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  const header = req.header("authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice(7) : null;
  if (!token) return res.status(401).json({ error: "missing bearer token" });

  const { data, error } = await admin.auth.getUser(token);
  if (error || !data.user) return res.status(401).json({ error: "invalid token" });

  req.userId = data.user.id;
  next();
}

export async function requireAdmin(
  req: AuthedRequest,
  res: Response,
  next: NextFunction,
) {
  if (!req.userId) return res.status(401).json({ error: "unauthenticated" });
  const { data } = await admin
    .from("users")
    .select("role")
    .eq("id", req.userId)
    .maybeSingle();
  if (data?.role !== "admin") return res.status(403).json({ error: "admin only" });
  next();
}
