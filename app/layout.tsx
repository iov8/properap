import type { Metadata, Viewport } from "next";
import "./globals.css";

const siteUrl = "https://steadfast.rockhillinnovation.com";

export const metadata: Metadata = {
  metadataBase: new URL(siteUrl),
  title: {
    default: "SteadFast Realty | Property, connected",
    template: "%s | SteadFast Realty",
  },
  description:
    "A modern real estate platform built for Jamaica's agents, brokerages, and property seekers.",
  applicationName: "SteadFast Realty",
  openGraph: {
    title: "SteadFast Realty",
    description: "Property, connected. Built for Jamaica.",
    url: siteUrl,
    siteName: "SteadFast Realty",
    locale: "en_JM",
    type: "website",
  },
  robots: { index: true, follow: true },
};

export const viewport: Viewport = {
  width: "device-width",
  initialScale: 1,
  themeColor: "#102c2a",
};

export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) {
  return (
    <html lang="en-JM">
      <body>{children}</body>
    </html>
  );
}
