import Link from "next/link";

export function PlatformAccountNav({ active }: { active: "profile" | "password" | "subscription" | "security" | "notifications" }) {
  const links: Array<[typeof active, string, string]> = [
    ["profile", "Profile", "/account"],
    ["password", "Password", "/account/password"],
    ["subscription", "Role", "/account/subscription"],
    ["security", "Security", "/account/security"],
    ["notifications", "Notifications", "/account/notifications"],
    ["profile", "Operations", "/staff"],
  ];

  return <nav aria-label="ProperAP staff account navigation" className="account-section-nav platform-account-nav">
    <span>ProperAP staff</span>
    {links.map(([key, label, href]) => <Link key={label} className={active === key && label !== "Operations" ? "active" : ""} href={href}>{label}</Link>)}
  </nav>;
}
