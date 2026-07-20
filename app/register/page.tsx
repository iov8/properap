import type { Metadata } from "next";
import Link from "next/link";
import { StatusMessage } from "@/app/components/status-message";
import { BrandLogo } from "@/app/components/brand-logo";
import { RegistrationForm } from "@/app/components/registration-form";
import { createClient } from "@/lib/supabase/server";

export const metadata: Metadata = { title: "Create account", description: "Create a free ProperAP property-search account.", robots: { index: false, follow: false } };
export const dynamic = "force-dynamic";

export default async function RegisterPage({
  searchParams,
}: {
  searchParams: Promise<{ error?: string; next?: string }>;
}) {
  const params = await searchParams;
  const supabase = await createClient();
  const { data: brokerages } = await supabase
    .from("brokerages")
    .select("id, display_name")
    .eq("status", "active")
    .order("display_name");
  return (
    <main className="auth-page">
      <section className="auth-intro">
        <BrandLogo />
        <span className="eyebrow"><i /> Start simply</span>
        <h1>Your property<br />account.</h1>
        <p>Regular users begin immediately. Professional registrations are reviewed before ProperAP activates workspace access.</p>
      </section>
      <section className="auth-card wide">
        <div><span className="eyebrow dark"><i /> Free registration</span><h2>Create account</h2></div>
        <StatusMessage error={params.error} />
        <RegistrationForm brokerages={brokerages ?? []} next={params.next ?? "/account"} />
        <p className="auth-switch">Already registered? <Link href="/sign-in">Sign in</Link></p>
      </section>
    </main>
  );
}
