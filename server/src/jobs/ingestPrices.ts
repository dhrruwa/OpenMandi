import { env } from "../env.js";
import { admin } from "../supabase.js";

// Daily cron: ingest mandi prices from data.gov.in (Agmarknet) into
// price_records. Schedule via Supabase scheduled function, GitHub Action, or
// `npm run cron:prices`. Maps the API's commodity names to our crops table.
const RESOURCE = "9ef84268-d588-465a-a308-a864a43d0070"; // Agmarknet daily prices

interface AgmarkRecord {
  commodity: string;
  market: string;
  min_price: string;
  max_price: string;
  modal_price: string;
  arrival_date: string;
}

export async function ingestPrices(): Promise<number> {
  if (!env.DATAGOV_API_KEY) throw new Error("DATAGOV_API_KEY not set");

  const url = new URL(`https://api.data.gov.in/resource/${RESOURCE}`);
  url.searchParams.set("api-key", env.DATAGOV_API_KEY);
  url.searchParams.set("format", "json");
  url.searchParams.set("limit", "500");

  const res = await fetch(url);
  if (!res.ok) throw new Error(`data.gov.in ${res.status}`);
  const json = (await res.json()) as { records?: AgmarkRecord[] };
  const records = json.records ?? [];

  const { data: crops } = await admin.from("crops").select("id, name");
  const cropByName = new Map((crops ?? []).map((c) => [c.name.toLowerCase(), c.id as string]));

  let inserted = 0;
  for (const r of records) {
    const cropId = cropByName.get(r.commodity.toLowerCase());
    if (!cropId) continue;
    const { error } = await admin.from("price_records").upsert(
      {
        crop_id: cropId,
        market: r.market,
        price_min: Number(r.min_price) || null,
        price_max: Number(r.max_price) || null,
        price_modal: Number(r.modal_price) || 0,
        date: r.arrival_date,
        source: "agmarknet",
      },
      { onConflict: "crop_id,market,date" },
    );
    if (!error) inserted++;
  }
  return inserted;
}

// Allow running directly: `npm run cron:prices`
if (import.meta.url === `file://${process.argv[1]}`) {
  ingestPrices()
    .then((n) => {
      console.log(`ingested ${n} price records`);
      process.exit(0);
    })
    .catch((e) => {
      console.error(e);
      process.exit(1);
    });
}
