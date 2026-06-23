import { createClient } from "@supabase/supabase-js";
import { env } from "./env.js";

// Service-role client — bypasses RLS. Used ONLY server-side for privileged
// operations (escrow transitions, KYC verification, price ingestion, audit).
// This key must never reach the mobile/web clients.
export const admin = createClient(env.SUPABASE_URL, env.SUPABASE_SERVICE_ROLE_KEY, {
  auth: { autoRefreshToken: false, persistSession: false },
});

export async function audit(
  actorId: string | null,
  action: string,
  entity: string,
  entityId: string | null,
  metadata: Record<string, unknown> = {},
  ip?: string,
) {
  await admin.from("audit_logs").insert({
    actor_id: actorId,
    action,
    entity,
    entity_id: entityId,
    ip: ip ?? null,
    metadata,
  });
}
