-- Counter / make an offer inside a thread (either party). Supersedes pending
-- offers, posts an offer message, notifies the other side.
create or replace function public.counter_offer(p_thread uuid, p_price int, p_qty numeric)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_f uuid; v_d uuid; v_listing uuid; v_unit produce_unit; v_crop text; v_offer uuid; v_other uuid;
begin
  select farmer_id, dealer_id, listing_id, crop_label into v_f, v_d, v_listing, v_crop
    from public.threads where id = p_thread;
  if v_f is null then raise exception 'thread not found'; end if;
  if auth.uid() not in (v_f, v_d) then raise exception 'forbidden'; end if;
  if p_price < 0 or p_qty <= 0 then raise exception 'invalid offer'; end if;

  select unit into v_unit from public.offers where thread_id = p_thread order by created_at desc limit 1;
  if v_unit is null and v_listing is not null then
    select unit into v_unit from public.listings where id = v_listing;
  end if;
  if v_unit is null then
    select b.unit into v_unit from public.threads t join public.buy_requests b on b.id = t.buy_request_id where t.id = p_thread;
  end if;
  if v_unit is null then v_unit := 'quintal'; end if;

  update public.offers set status = 'declined' where thread_id = p_thread and status = 'pending';

  insert into public.offers(thread_id, listing_id, from_user, price, quantity, unit, status)
  values (p_thread, v_listing, auth.uid(), p_price, p_qty, v_unit, 'pending') returning id into v_offer;

  insert into public.messages(thread_id, sender_id, type, offer_id)
  values (p_thread, auth.uid(), 'offer', v_offer);

  v_other := case when auth.uid() = v_f then v_d else v_f end;
  perform public.notify(v_other, 'offer', 'New price for ' || coalesce(nullif(v_crop,''),'your deal'),
                        '₹' || p_price || '/qtl', jsonb_build_object('thread', p_thread));
  perform public.audit('offer.counter', 'offers', v_offer);
  return v_offer;
end $$;
grant execute on function public.counter_offer(uuid,int,numeric) to authenticated;

-- Accept an offer — either participant may accept, but NOT the one who proposed
-- it; guarded to pending only. Order parties come from the thread.
create or replace function public.accept_offer(p_offer uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_thread uuid; v_listing uuid; v_farmer uuid; v_dealer uuid; v_from uuid; v_status offer_status;
  v_price int; v_qty numeric; v_unit produce_unit; v_crop text; v_emoji text; v_order uuid;
begin
  select o.thread_id, o.listing_id, o.price, o.quantity, o.unit, o.from_user, o.status,
         t.farmer_id, t.dealer_id, t.crop_label, t.emoji
    into v_thread, v_listing, v_price, v_qty, v_unit, v_from, v_status, v_farmer, v_dealer, v_crop, v_emoji
  from public.offers o join public.threads t on t.id = o.thread_id
  where o.id = p_offer;
  if v_farmer is null then raise exception 'offer not found'; end if;
  if auth.uid() not in (v_farmer, v_dealer) then raise exception 'forbidden'; end if;
  if v_status <> 'pending' then raise exception 'offer is no longer pending'; end if;
  if v_from = auth.uid() then raise exception 'cannot accept your own offer'; end if;

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
  perform public.notify(v_farmer, 'order', 'Deal agreed', 'Order created',
                        jsonb_build_object('order', v_order));
  perform public.audit('offer.accept', 'orders', v_order);
  return v_order;
end $$;
grant execute on function public.accept_offer(uuid) to authenticated;
