-- Farmer responds to a dealer's buy requirement → starts/reuses a chat thread,
-- bumps the response count, notifies the dealer. Returns the thread id.
create or replace function public.respond_to_requirement(p_req uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_dealer uuid; v_crop text; v_emoji text; v_thread uuid;
begin
  if not public.is_kyc_verified() then raise exception 'KYC not verified'; end if;
  select b.dealer_id, c.name, c.emoji into v_dealer, v_crop, v_emoji
  from public.buy_requests b join public.crops c on c.id = b.crop_id
  where b.id = p_req;
  if v_dealer is null then raise exception 'requirement not found'; end if;
  if v_dealer = auth.uid() then raise exception 'cannot respond to your own requirement'; end if;

  select id into v_thread from public.threads
   where buy_request_id = p_req and farmer_id = auth.uid() and dealer_id = v_dealer;
  if v_thread is null then
    insert into public.threads(buy_request_id, farmer_id, dealer_id, crop_label, emoji)
    values (p_req, auth.uid(), v_dealer, v_crop, v_emoji) returning id into v_thread;
    insert into public.messages(thread_id, sender_id, type, body)
    values (v_thread, auth.uid(), 'text', 'Hi, I can supply your ' || v_crop || ' requirement.');
    update public.buy_requests set responses = responses + 1 where id = p_req;
    perform public.notify(v_dealer, 'message', 'A farmer can supply your ' || v_crop,
                          'Tap to open the chat', jsonb_build_object('thread', v_thread));
  end if;
  perform public.audit('requirement.respond', 'buy_requests', p_req);
  return v_thread;
end $$;
grant execute on function public.respond_to_requirement(uuid) to authenticated;
