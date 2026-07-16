import type { Metadata } from "next";
import Link from "next/link";
import { connection } from "next/server";

export const metadata: Metadata = {
  title: "Property Search",
  description: "Search property listings with SteadFast Realty.",
};

type SearchParams = Promise<Record<string, string | string[] | undefined>>;

function cleanParameter(value: string | string[] | undefined, maxLength: number) {
  const first = Array.isArray(value) ? value[0] : value;
  return first?.trim().slice(0, maxLength) ?? "";
}

export default async function Properties({ searchParams }: { searchParams: SearchParams }) {
  await connection();
  const params = await searchParams;
  const location = cleanParameter(params.location, 80);
  const type = cleanParameter(params.type, 30);
  const intent = cleanParameter(params.intent, 12) === "rent" ? "rent" : "buy";

  return (
    <main className="search-page">
      <header className="site-header search-header">
        <Link className="brand" href="/" aria-label="SteadFast Realty home">
          <span className="brand-mark" aria-hidden="true">S</span>
          <span>SteadFast</span>
          <small>Realty</small>
        </Link>
        <Link className="outline-button" href="/">Back home</Link>
      </header>
      <section className="search-stage">
        <span className="eyebrow dark"><i /> Property search preview</span>
        <h1>{location ? `Exploring ${location}` : `Find a place to ${intent}`}</h1>
        <p>
          {type ? `${type.charAt(0).toUpperCase()}${type.slice(1)} listings` : "All property types"} will appear here after the first brokerage inventory is approved.
        </p>
        <div className="empty-state">
          <div className="empty-state-icon"><span /></div>
          <div>
            <strong>The search experience is ready.</strong>
            <p>We&apos;re connecting the approved listing database next—no placeholder properties, no misleading results.</p>
          </div>
        </div>
        <Link className="solid-button" href="/">Refine your search</Link>
      </section>
    </main>
  );
}
