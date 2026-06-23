import { Router } from "express";
import { z } from "zod";
import { requireAuth, type AuthedRequest } from "../middleware/auth.js";
import { admin, audit } from "../supabase.js";
import { createRazorpayOrder, verifyWebhookSignature } from "../providers/razorpay.js";

export const paymentsRouter = Router();

// Create a Razorpay order for an OpenMandi order. Amount is read from the DB
// (server-computed total_amount) — never from the client.
paymentsRouter.post("/order", requireAuth, async (req: AuthedRequest, res) => {
  const body = z.object({ orderId: z.string().uuid() }).safeParse(req.body);
  if (!body.success) return res.status(400).json({ error: "invalid orderId" });

  const { data: order } = await admin
    .from("orders")
    .select("id, dealer_id, total_amount, status")
    .eq("id", body.data.orderId)
    .maybeSingle();
  if (!order) return res.status(404).json({ error: "order not found" });
  if (order.dealer_id !== req.userId) return res.status(403).json({ error: "not your order" });

  const rp = await createRazorpayOrder(order.total_amount, `om_${order.id}`);
  await admin.from("payments").upsert({
    order_id: order.id,
    amount: order.total_amount,
    method: "razorpay",
    gateway_ref: rp.id,
    escrow_status: "none",
  });
  await audit(req.userId!, "payment.order.create", "orders", order.id, { rp: rp.id }, req.ip);
  res.json({ razorpayOrderId: rp.id, amount: rp.amount, currency: rp.currency });
});

// Webhook (raw body). On capture: hold escrow + move order to 'confirmed'.
paymentsRouter.post("/webhook", async (req, res) => {
  const signature = req.header("x-razorpay-signature") ?? "";
  const raw = (req as unknown as { rawBody?: string }).rawBody ?? "";
  if (!verifyWebhookSignature(raw, signature)) {
    return res.status(400).json({ error: "bad signature" });
  }
  const event = JSON.parse(raw) as {
    event: string;
    payload?: { payment?: { entity?: { order_id?: string } } };
  };
  const rpOrderId = event.payload?.payment?.entity?.order_id;
  if (event.event === "payment.captured" && rpOrderId) {
    const { data: pay } = await admin
      .from("payments")
      .update({ escrow_status: "held" })
      .eq("gateway_ref", rpOrderId)
      .select("order_id")
      .maybeSingle();
    if (pay?.order_id) {
      await admin.from("orders").update({ status: "confirmed" }).eq("id", pay.order_id);
      await audit(null, "payment.captured", "orders", pay.order_id, {}, req.ip);
    }
  }
  res.json({ ok: true });
});

// Release escrow to the farmer once the dealer confirms delivery.
paymentsRouter.post("/:orderId/release", requireAuth, async (req: AuthedRequest, res) => {
  const orderId = z.string().uuid().safeParse(req.params.orderId);
  if (!orderId.success) return res.status(400).json({ error: "invalid orderId" });

  const { data: order } = await admin
    .from("orders")
    .select("id, dealer_id, status")
    .eq("id", orderId.data)
    .maybeSingle();
  if (!order) return res.status(404).json({ error: "order not found" });
  if (order.dealer_id !== req.userId) return res.status(403).json({ error: "not your order" });
  if (order.status !== "delivered") return res.status(409).json({ error: "order not delivered yet" });

  await admin.from("payments").update({ escrow_status: "released" }).eq("order_id", order.id);
  await admin.from("orders").update({ status: "completed" }).eq("id", order.id);
  // TODO: real payout to farmer's verified bank/UPI via RazorpayX.
  await audit(req.userId!, "payment.escrow.release", "orders", order.id, {}, req.ip);
  res.json({ released: true });
});
