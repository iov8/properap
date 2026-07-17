import Link from "next/link";
import { connection } from "next/server";
import { BrandLogo } from "@/app/components/brand-logo";
import { PropertySearchCard } from "@/app/components/property-search-card";
import { publicPageMetadata } from "@/lib/seo/metadata";

export const metadata = publicPageMetadata({
  title: "Property, connected",
  description: "Discover Jamaican property and work with trusted agents and brokerages through SteadFast Realty.",
  path: "/",
  keywords: ["Jamaica real estate", "Jamaica property", "Jamaica real estate agents"],
});

const platformHighlights = [
  {
    number: "01",
    title: "Listings that move with confidence",
    body: "A clear brokerage approval trail keeps every price, status, and major edit accountable.",
  },
  {
    number: "02",
    title: "Your brand, beautifully presented",
    body: "Agents and brokerages receive focused web experiences designed to make their inventory shine.",
  },
  {
    number: "03",
    title: "Built for trusted collaboration",
    body: "Share approved listings across agent websites while preserving ownership and contact choice.",
  },
];

export default async function Home() {
  await connection();

  return (
    <main>
      <header className="site-header">
        <BrandLogo />
        <nav className="desktop-nav" aria-label="Primary navigation">
          <Link href="/properties">Buy</Link>
          <Link href="/properties?intent=rent">Rent</Link>
          <a href="#platform">For professionals</a>
        </nav>
        <div className="header-actions">
          <span className="launch-note">Jamaica marketplace</span>
          <Link className="outline-button" href="/sign-in">Sign in</Link>
        </div>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <span className="eyebrow"><i /> Built for Jamaica</span>
          <h1>Property,<br /><em>connected.</em></h1>
          <p className="hero-intro">
            A calmer, clearer way to discover property and work with trusted real estate professionals.
          </p>

          <PropertySearchCard />

          <div className="hero-footnote">
            <span>Verified brokerage workflow</span>
            <span>Agent-led service</span>
            <span>International-ready</span>
          </div>
        </div>

        <div className="island-panel" aria-label="Stylized map of Jamaica">
          <div className="map-grid" />
          <div className="map-label map-label-one"><i /> Kingston</div>
          <div className="map-label map-label-two"><i /> Montego Bay</div>
          <div className="map-label map-label-three"><i /> Ocho Rios</div>
          <div className="island-shape">
            <div className="island-glow" />
          </div>
          <div className="map-card">
            <span>From local reach</span>
            <strong>to global discovery.</strong>
            <p>Structured for international listing connections as SteadFast grows.</p>
          </div>
        </div>
      </section>

      <section className="platform-section" id="platform">
        <div className="section-heading">
          <span className="eyebrow dark"><i /> One connected platform</span>
          <h2>Real estate should feel<br />easy to move through.</h2>
          <p>SteadFast brings the work of agents and brokerages into one thoughtful, approval-led experience.</p>
        </div>
        <div className="highlight-grid">
          {platformHighlights.map((item) => (
            <article key={item.number}>
              <span>{item.number}</span>
              <h3>{item.title}</h3>
              <p>{item.body}</p>
            </article>
          ))}
        </div>
      </section>

      <section className="roles-strip">
        <div>
          <span>For property seekers</span>
          <strong>Search simply. Choose your agent.</strong>
        </div>
        <div>
          <span>For agents</span>
          <strong>Present every listing at its best.</strong>
        </div>
        <div>
          <span>For brokerages</span>
          <strong>Lead your people and inventory.</strong>
        </div>
      </section>

      <footer>
        <BrandLogo compact />
        <p>Jamaica&apos;s modern real estate platform.</p>
        <span>Prototype release · 2026</span>
      </footer>
    </main>
  );
}
