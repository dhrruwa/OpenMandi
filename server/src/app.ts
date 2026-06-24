import { Hono } from "hono";
import { cors } from "hono/cors";
import { withSupabase } from "@supabase/server/adapters/hono";
import type { SupabaseContext } from "@supabase/server";

// The SDK reads SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY /
// SUPABASE_JWKS_URL from the environment. `ctx.supabase` is RLS-scoped to the
// caller; `ctx.supabaseAdmin` bypasses RLS (server-only — never expose freely).
type Env = { Variables: { supabaseContext: SupabaseContext } };

export const app = new Hono<Env>();

// Restrict CORS to an explicit allowlist (CORS_ORIGINS, comma-separated).
// Defaults to localhost dev only — never a wildcard on an authenticated API.
const allowedOrigins = (process.env.CORS_ORIGINS ??
  "http://localhost:5173,http://localhost:5179")
  .split(",")
  .map((o) => o.trim())
  .filter(Boolean);

app.use(
  "*",
  cors({
    origin: (origin) => (allowedOrigins.includes(origin) ? origin : null),
    allowMethods: ["GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"],
    allowHeaders: ["Authorization", "Content-Type", "apikey"],
    credentials: true,
    maxAge: 600,
  }),
);

// ── public ────────────────────────────────────────────────
app.get("/health", (c) =>
  c.json({ ok: true, service: "openmandi-server", auth: "@supabase/server" }),
);

// ── user-scoped routes: require a valid Supabase user JWT; RLS applies ──
const me = new Hono<Env>();
me.use("*", withSupabase({ auth: "user" }));

// The signed-in user's own listings — gated by RLS through ctx.supabase.
me.get("/listings", async (c) => {
  const { supabase } = c.var.supabaseContext;
  const { data, error } = await supabase.from("listings").select();
  if (error) return c.json({ error: error.message }, 400);
  return c.json(data);
});

// The user's claims (from the verified JWT).
me.get("/claims", (c) => c.json(c.var.supabaseContext.userClaims ?? null));

app.route("/me", me);

// ── admin routes: caller must present the secret key; bypasses RLS ──
const admin = new Hono<Env>();
admin.use("*", withSupabase({ auth: "secret" }));

// Example privileged read across all users (no RLS) — for back-office tooling.
admin.get("/users", async (c) => {
  const { supabaseAdmin } = c.var.supabaseContext;
  const { data, error } = await supabaseAdmin
    .from("users")
    .select("id, full_name, role, kyc_status, created_at")
    .order("created_at", { ascending: false });
  if (error) return c.json({ error: error.message }, 400);
  return c.json(data);
});

app.route("/admin", admin);
