import { NextResponse } from "next/server";
import { z } from "zod";
import { createClient } from "@/lib/supabase/server";

const payloadSchema = z.object({ listingId: z.string().uuid(), saved: z.boolean() });

async function currentPerson() {
  const supabase = await createClient();
  const { data: { user } } = await supabase.auth.getUser();
  if (!user) return { supabase, personId: null };
  const { data: person } = await supabase.from("people").select("id").eq("auth_user_id", user.id).maybeSingle();
  return { supabase, personId: person?.id ?? null };
}

export async function GET(request: Request) {
  const listingId = new URL(request.url).searchParams.get("listingId");
  if (!z.string().uuid().safeParse(listingId).success) return NextResponse.json({ error: "Invalid listing." }, { status: 400 });
  const { supabase, personId } = await currentPerson();
  if (!personId) return NextResponse.json({ saved: false }, { status: 401 });
  const { data } = await supabase.from("consumer_saved_listings").select("listing_id").eq("person_id", personId).eq("listing_id", listingId).maybeSingle();
  return NextResponse.json({ saved: Boolean(data) }, { headers: { "Cache-Control": "private, no-store" } });
}

export async function POST(request: Request) {
  const parsed = payloadSchema.safeParse(await request.json().catch(() => null));
  if (!parsed.success) return NextResponse.json({ error: "Invalid request." }, { status: 400 });
  const { supabase, personId } = await currentPerson();
  if (!personId) return NextResponse.json({ error: "Sign in required." }, { status: 401 });
  const query = parsed.data.saved
    ? supabase.from("consumer_saved_listings").upsert({ person_id: personId, listing_id: parsed.data.listingId }, { onConflict: "person_id,listing_id" })
    : supabase.from("consumer_saved_listings").delete().eq("person_id", personId).eq("listing_id", parsed.data.listingId);
  const { error } = await query;
  if (error) return NextResponse.json({ error: "Your saved listings could not be updated." }, { status: 400 });
  return NextResponse.json({ saved: parsed.data.saved });
}
