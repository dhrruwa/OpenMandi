-- Enable Supabase Realtime on the tables the apps subscribe to, so listings,
-- offers, orders, messages and notifications push live to clients.
do $$
declare t text;
begin
  foreach t in array array['listings','offers','orders','messages','notifications','threads'] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;
  end loop;
end $$;
