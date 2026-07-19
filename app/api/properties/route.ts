import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { parsePropertySearchParams, searchPublicListings } from "@/lib/public-property-search";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const filters = parsePropertySearchParams(Object.fromEntries(url.searchParams));
  const supabase = await createClient();
  const { data: rates } = await supabase.from("exchange_rate_snapshots").select("jmd_per_usd,cad_per_usd,gbp_per_usd,provider_updated_at").order("fetched_at", { ascending: false }).limit(1).maybeSingle();
  const results = await searchPublicListings(supabase, filters, rates);
  return NextResponse.json(results, { headers: { "Cache-Control": "no-store" } });
}
