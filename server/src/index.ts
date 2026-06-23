import express, { type NextFunction, type Request, type Response } from "express";
import helmet from "helmet";
import cors from "cors";
import rateLimit from "express-rate-limit";
import { env, corsOrigins } from "./env.js";
import { kycRouter } from "./routes/kyc.js";
import { paymentsRouter } from "./routes/payments.js";

const app = express();

// security headers
app.use(helmet());
app.set("trust proxy", 1);

// strict CORS allowlist
app.use(
  cors({
    origin: (origin, cb) => {
      if (!origin || corsOrigins.includes(origin)) return cb(null, true);
      cb(new Error("origin not allowed"));
    },
    credentials: true,
  }),
);

// JSON parser that also captures the raw body (needed for webhook signatures)
app.use(
  express.json({
    limit: "256kb",
    verify: (req, _res, buf) => {
      (req as unknown as { rawBody: string }).rawBody = buf.toString("utf8");
    },
  }),
);

// rate limits — global + stricter on sensitive routes
app.use(rateLimit({ windowMs: 60_000, max: 120, standardHeaders: true, legacyHeaders: false }));
const sensitive = rateLimit({ windowMs: 60_000, max: 15 });

app.get("/health", (_req, res) => res.json({ ok: true, env: env.NODE_ENV }));

app.use("/kyc", sensitive, kycRouter);
app.use("/payments", paymentsRouter);

// 404 + error handler (never leak internals)
app.use((_req, res) => res.status(404).json({ error: "not found" }));
app.use((err: unknown, _req: Request, res: Response, _next: NextFunction) => {
  const message = err instanceof Error ? err.message : "internal error";
  if (env.NODE_ENV !== "production") console.error(err);
  res.status(500).json({ error: env.NODE_ENV === "production" ? "internal error" : message });
});

app.listen(env.PORT, () => {
  console.log(`OpenMandi server on :${env.PORT} (${env.NODE_ENV})`);
});
