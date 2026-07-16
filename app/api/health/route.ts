import { NextResponse } from "next/server";

export const dynamic = "force-dynamic";

export function GET() {
  const supabaseConfigured = Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL &&
      process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY,
  );

  return NextResponse.json(
    {
      service: "steadfast-web",
      status: "ok",
      integrations: { supabase: supabaseConfigured ? "configured" : "pending" },
    },
    {
      headers: {
        "Cache-Control": "no-store, private",
      },
    },
  );
}
