-- ============================================================
-- OpenMandi — RPCs for atomic, server-side trade actions. All are
-- SECURITY DEFINER (bypass RLS) and re-check ownership with auth.uid().
-- ============================================================

-- helper: write an audit row (definer)
create or replace function public.audit(p_action text, p_entity text, p_entity_id uuid, p_meta jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.audit_logs(actor_id, action, entity, entity_id, metadata)
  values (auth.uid(), p_action, p_entity, p_entity_id, coalesce(p_meta,'{}'::jsonb));
$$;

create or replace function public.notify(p_user uuid, p_type notif_type, p_title text, p_body text, p_payload jsonb default '{}')
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(user_id, type, title, body, payload)
  values (p_user, p_type, p_title, p_body, coalesce(p_payload,'{}'::jsonb));
$$;

-- DEMO ONLY: auto-verify the caller's KYC. In production this is replaced by
-- the licensed Aadhaar/GST provider response handled by the Express service
-- (service role), which sets kyc_status after a real eKYC check.
create or replace function public.dev_autoverify_kyc()
returns void language plpgsql security definer set search_path = public as $$
begin
  perform set_config('app.bypass_guard', 'on', true);  -- tx-local; lets this RPC set kyc_status
  update public.users set kyc_status = 'verified' where id = auth.uid();
  perform public.audit('kyc.autoverify(demo)', 'users', auth.uid());
end $$;

-- DEALER: make an offer on a listing. Creates or reuses a thread, an offer, and
-- an offer message. Does NOT create an order — the farmer accepts first.
create or replace function public.make_offer(p_listing uuid, p_price int, p_qty numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_farmer uuid; v_crop text; v_emoji text; v_unit produce_unit; v_thread uuid; v_offer uuid;
begin
  if not public.is_kyc_verified() then raise exception 'KYC not verified'; end if;

  select l.farmer_id, c.name, c.emoji, l.unit
    into v_farmer, v_crop, v_emoji, v_unit
  from public.listings l join public.crops c on c.id = l.crop_id
  where l.id = p_listing;
  if v_farmer is null then raise exception 'listing not found'; end if;
  if v_farmer = auth.uid() then raise exception 'cannot offer on your own listing'; end if;

  select id into v_thread from public.threads
    where listing_id = p_listing and farmer_id = v_farmer and dealer_id = auth.uid();
  if v_thread is null then
    insert into public.threads(listing_id, farmer_id, dealer_id, crop_label, emoji)
    values (p_listing, v_farmer, auth.uid(), v_crop, v_emoji) returning id into v_thread;
  end if;

  insert into public.offers(thread_id, listing_id, from_user, price, quantity, unit)
  values (v_thread, p_listing, auth.uid(), p_price, p_qty, v_unit) returning id into v_offer;

  insert into public.messages(thread_id, sender_id, type, offer_id)
  values (v_thread, auth.uid(), 'offer', v_offer);

  update public.listings set status = 'offers', offers = offers + 1 where id = p_listing;

  perform public.notify(v_farmer, 'offer', 'New offer on your ' || v_crop,
                        '₹' || p_price || '/qtl', jsonb_build_object('thread', v_thread));
  perform public.audit('offer.create', 'offers', v_offer);
  return v_thread;
end $$;

-- FARMER: accept an offer → declines siblings, marks listing sold, creates the order.
create or replace function public.accept_offer(p_offer uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_thread uuid; v_listing uuid; v_farmer uuid; v_dealer uuid;
  v_price int; v_qty numeric; v_unit produce_unit; v_crop text; v_emoji text; v_order uuid;
begin
  select o.thread_id, o.listing_id, o.price, o.quantity, o.unit,
         t.farmer_id, t.dealer_id, t.crop_label, t.emoji
    into v_thread, v_listing, v_price, v_qty, v_unit, v_farmer, v_dealer, v_crop, v_emoji
  from public.offers o join public.threads t on t.id = o.thread_id
  where o.id = p_offer;
  if v_farmer is null then raise exception 'offer not found'; end if;
  if v_farmer <> auth.uid() then raise exception 'only the listing owner can accept'; end if;

  update public.offers set status = 'accepted' where id = p_offer;
  update public.offers set status = 'declined'
    where thread_id = v_thread and id <> p_offer and status = 'pending';
  if v_listing is not null then
    update public.listings set status = 'sold' where id = v_listing;
  end if;

  insert into public.orders(listing_id, farmer_id, dealer_id, crop_label, emoji,
                            final_price, quantity, unit, total_amount, status)
  values (v_listing, v_farmer, v_dealer, v_crop, v_emoji, v_price, v_qty, v_unit, 0, 'accepted')
  returning id into v_order;

  perform public.notify(v_dealer, 'order', 'Offer accepted', 'Pay into escrow to confirm',
                        jsonb_build_object('order', v_order));
  perform public.audit('offer.accept', 'orders', v_order);
  return v_order;
end $$;

-- order lifecycle (participant-checked). Real escrow money moves in Phase 2
-- via the Express service + Razorpay; here we advance the contract status.
create or replace function public.advance_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_status order_status; v_f uuid; v_d uuid;
begin
  select status, farmer_id, dealer_id into v_status, v_f, v_d from public.orders where id = p_order;
  if v_f is null then raise exception 'order not found'; end if;
  if auth.uid() not in (v_f, v_d) and not public.is_admin() then raise exception 'forbidden'; end if;

  update public.orders set status = case v_status
      when 'accepted'   then 'confirmed'
      when 'confirmed'  then 'in_transit'
      when 'in_transit' then 'delivered'
      else v_status end
  where id = p_order;
  perform public.audit('order.advance', 'orders', p_order, jsonb_build_object('from', v_status));
end $$;

create or replace function public.complete_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_f uuid; v_d uuid;
begin
  select farmer_id, dealer_id into v_f, v_d from public.orders where id = p_order;
  if v_f is null then raise exception 'order not found'; end if;
  if auth.uid() not in (v_f, v_d) and not public.is_admin() then raise exception 'forbidden'; end if;

  update public.orders set status = 'completed' where id = p_order and status = 'delivered';
  perform public.notify(v_f, 'payout', 'Order completed', 'Escrow released to your wallet',
                        jsonb_build_object('order', p_order));
  perform public.audit('order.complete', 'orders', p_order);
end $$;

grant execute on function
  public.dev_autoverify_kyc(), public.make_offer(uuid,int,numeric),
  public.accept_offer(uuid), public.advance_order(uuid), public.complete_order(uuid)
to authenticated;
