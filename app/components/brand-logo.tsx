import Image from "next/image";
import Link from "next/link";

export function BrandLogo({ compact = false }: { compact?: boolean }) {
  return (
    <Link className={`brand-logo${compact ? " compact" : ""}`} href="/" aria-label="SteadFast Realty home">
      <Image
        src="/steadfast-logo.png"
        alt="SteadFast Realty"
        width={1536}
        height={1024}
        priority
        sizes={compact ? "108px" : "132px"}
      />
    </Link>
  );
}
