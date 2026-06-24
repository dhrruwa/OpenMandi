import { serve } from "@hono/node-server";
import { app } from "./app.js";

// Serves the @supabase/server (Hono) app on Node. Env vars
// (SUPABASE_URL / SUPABASE_PUBLISHABLE_KEY / SUPABASE_SECRET_KEY /
// SUPABASE_JWKS_URL) are loaded from .env via the npm scripts (--env-file).
const port = Number(process.env.PORT ?? 8787);

serve({ fetch: app.fetch, port }, (info) => {
  console.log(`OpenMandi server (@supabase/server) listening on :${info.port}`);
});
