import Link from "next/link";
import { PublicFooter, PublicHeader } from "@/app/components/public-chrome";
import { PlansPricing } from "@/app/components/plans-pricing";
import { publicPageMetadata } from "@/lib/seo/metadata";

export const metadata = publicPageMetadata({ title: "Plans and pricing | ProperAP", description: "Simple professional and brokerage plans for Jamaica's connected real estate platform.", path: "/plans", keywords: ["Jamaica real estate software", "real estate agent website", "brokerage listing management"] });

export default function PlansPage() {
  const structuredData = { "@context": "https://schema.org", "@type": "Product", name: "ProperAP real estate platform", description: "Professional listing, website, brokerage workflow, and analytics software for Jamaica.", offers: [{ "@type": "Offer", name: "Independent Agent monthly membership", price: 40, priceCurrency: "USD" }, { "@type": "Offer", name: "Brokerage Agent monthly membership", price: 30, priceCurrency: "USD" }, { "@type": "Offer", name: "Broker Core monthly membership", price: 150, priceCurrency: "USD" }, { "@type": "Offer", name: "Broker Growth monthly membership", price: 300, priceCurrency: "USD" }] };
  return <main className="public-page plans-page">
    <PublicHeader />
    <section className="plans-hero"><span>Plans for every stage</span><h1>Build your property business on one connected platform.</h1><p>Choose an annual commitment for a predictable 12-month term, with your first month of ProperAP access free.</p></section>
    <PlansPricing />
    <section className="plans-explainer"><div><span>One person, one seat</span><h2>Multiple responsibilities do not mean duplicate professional fees.</h2></div><div><p>An agent who is also brokerage staff pays for one Professional seat and counts as an agent for plan capacity. A brokerage subscription provides company controls and capacity; active professional seats are separate.</p><p>Brokerages may pay professional subscriptions centrally. Consumer access remains free.</p></div></section>
    <section className="plans-faq"><span>Good to know</span><h2>Clear terms before you choose.</h2><div><article><h3>Can an independent agent join?</h3><p>Yes. Independent agents receive self-managed listing authority and pay the Independent Agent rate.</p></article><article><h3>How does annual membership work?</h3><p>Your first month is free. ProperAP then bills the standard monthly rate for the remaining 11 months of the 12-month commitment.</p></article><article><h3>Can we move between plans?</h3><p>Yes. Your new rate begins on the next billing date. ProperAP does not issue refunds or account credits for previously billed periods.</p></article></div></section>
    <section className="plans-cta"><h2>Ready to build a stronger property presence?</h2><Link className="primary-button" href="/register">Get started</Link><Link href="/support">Ask a question</Link></section>
    <PublicFooter />
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData).replace(/</g, "\\u003c") }} />
  </main>;
}
