import Link from "next/link";
import { PublicFooter, PublicHeader } from "@/app/components/public-chrome";
import { publicPageMetadata } from "@/lib/seo/metadata";

export const metadata = publicPageMetadata({ title: "Plans and pricing | ProperAP", description: "Simple professional and brokerage plans for Jamaica's connected real estate platform.", path: "/plans", keywords: ["Jamaica real estate software", "real estate agent website", "brokerage listing management"] });

const plans = [
  { name: "Consumer", price: "Free", unit: "", description: "For buyers, renters, sellers, and property explorers.", features: ["Search Jamaican properties", "Save preferred currency", "Contact the right property agent", "No subscription required"], cta: "Search properties", href: "/properties", featured: false },
  { name: "Professional", price: "US$50", unit: "per professional / month", description: "For affiliated agents and brokerage staff building a serious digital presence.", features: ["Agent website and subdomain", "Create and manage listings", "Listing sharing between agents", "Inquiries and notifications", "Performance analytics"], cta: "Create an account", href: "/register", featured: false },
  { name: "Broker Core", price: "US$150", unit: "per brokerage / month", description: "For growing brokerages that need approval, team, and inventory control.", features: ["Up to 20 affiliated agents", "Up to 5 non-agent staff", "Brokerage website", "Listing approval workflow", "Team and brokerage analytics", "Professional seats billed separately"], cta: "Talk to ProperAP", href: "/support", featured: true },
  { name: "Broker Growth", price: "US$300", unit: "per brokerage / month", description: "For established brokerages with larger teams and reporting needs.", features: ["Up to 75 affiliated agents", "Up to 15 non-agent staff", "Advanced brokerage reporting", "Priority onboarding", "Centralized billing option", "Professional seats billed separately"], cta: "Choose Growth", href: "/support", featured: false },
  { name: "Enterprise", price: "Custom", unit: "", description: "For networks operating above Growth limits or requiring tailored support.", features: ["Custom team capacity", "Data migration planning", "Integration support", "Service-level options", "Volume pricing discussion"], cta: "Contact us", href: "/support", featured: false },
] as const;

export default function PlansPage() {
  const structuredData = { "@context": "https://schema.org", "@type": "Product", name: "ProperAP real estate platform", description: "Professional listing, website, brokerage workflow, and analytics software for Jamaica.", offers: plans.filter((plan) => plan.price !== "Custom").map((plan) => ({ "@type": "Offer", name: plan.name, price: plan.price === "Free" ? 0 : Number(plan.price.replace(/\D/g, "")), priceCurrency: "USD" })) };
  return <main className="public-page plans-page">
    <PublicHeader />
    <section className="plans-hero"><span>Plans for every stage</span><h1>Build your property business on one connected platform.</h1><p>Start with the tools you need today, then expand your team without changing systems.</p></section>
    <section className="plans-grid" aria-label="ProperAP subscription plans">{plans.map((plan) => <article className={`plan-card${plan.featured ? " featured" : ""}`} key={plan.name}>{plan.featured ? <span className="plan-recommended">Most popular</span> : null}<h2>{plan.name}</h2><div className="plan-price">{plan.price}</div>{plan.unit ? <p className="plan-unit">{plan.unit}</p> : null}<p>{plan.description}</p><ul>{plan.features.map((feature) => <li key={feature}>{feature}</li>)}</ul><Link className={plan.featured ? "primary-button" : "outline-button"} href={plan.href}>{plan.cta}</Link></article>)}</section>
    <section className="plans-explainer"><div><span>One person, one seat</span><h2>Multiple responsibilities do not mean duplicate professional fees.</h2></div><div><p>An agent who is also brokerage staff pays for one Professional seat and counts as an agent for plan capacity. A brokerage subscription provides company controls and capacity; active professional seats are separate.</p><p>Brokerages may pay professional subscriptions centrally. Consumer access remains free.</p></div></section>
    <section className="plans-faq"><span>Good to know</span><h2>Clear terms before you choose.</h2><div><article><h3>Can an independent agent join?</h3><p>No. Every ProperAP agent must be affiliated with and approved by a brokerage.</p></article><article><h3>Are annual discounts included?</h3><p>Not in the current base plan. The published prices are monthly.</p></article><article><h3>Can we move between plans?</h3><p>Yes. A brokerage can move as its agent and staff capacity changes.</p></article></div></section>
    <section className="plans-cta"><h2>Ready to build a stronger property presence?</h2><Link className="primary-button" href="/register">Get started</Link><Link href="/support">Ask a question</Link></section>
    <PublicFooter />
    <script type="application/ld+json" dangerouslySetInnerHTML={{ __html: JSON.stringify(structuredData).replace(/</g, "\\u003c") }} />
  </main>;
}
