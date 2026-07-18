"use client";

import Image from "next/image";
import Link from "next/link";
import { useState } from "react";

export type BrokerageTeamMember = { id: string; slug: string; displayName: string; photoAssetId: string | null; isPrincipal: boolean };

function initials(name: string) { return name.split(/\s+/).map((part) => part[0]).join("").slice(0, 2).toUpperCase(); }

export function BrokerageTeamGrid({ members }: { members: BrokerageTeamMember[] }) {
  const [page, setPage] = useState(0);
  const pageCount = Math.ceil(members.length / 8);
  const visibleMembers = members.slice(page * 8, page * 8 + 8);
  return <>
    <div className="brokerage-team-grid">
      {visibleMembers.map((member) => <Link key={member.id} href={`/agents/${member.slug}`} target="_blank" rel="noopener noreferrer" className="brokerage-team-card" aria-label={`Open ${member.displayName}'s website in a new tab`}>
        <div className="brokerage-team-photo">{member.photoAssetId ? <Image src={`/media/listings/${member.photoAssetId}/card.webp?v=${member.photoAssetId}`} alt={`${member.displayName} professional photograph`} width={480} height={480} unoptimized /> : <span aria-hidden="true">{initials(member.displayName)}</span>}</div>
        <strong>{member.displayName}</strong>
      </Link>)}
    </div>
    {pageCount > 1 ? <nav className="brokerage-team-pagination" aria-label="Brokerage team pages">{Array.from({ length: pageCount }, (_, index) => <button key={index} type="button" className={index === page ? "active" : ""} onClick={() => setPage(index)} aria-current={index === page ? "page" : undefined} aria-label={`Show team page ${index + 1}`}>{index + 1}</button>)}</nav> : null}
  </>;
}
