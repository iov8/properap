"use client";

import { useState } from "react";
import { registerAction } from "@/app/actions/auth";

type Brokerage = { id: string; display_name: string };
type RegistrationRole = "consumer" | "agent" | "broker";

export function RegistrationForm({ brokerages, next }: { brokerages: Brokerage[]; next: string }) {
  const [role, setRole] = useState<RegistrationRole>("consumer");

  return (
    <form action={registerAction} className="stack-form two-column">
      <input type="hidden" name="next" value={next} />
      <input type="hidden" name="requestedRole" value={role} />
      <fieldset className="registration-role-picker full">
        <legend>Account type</legend>
        <p>Choose how you will use ProperAP. Regular User accounts are active immediately; professional accounts begin as inactive while ProperAP reviews the registration.</p>
        <div className="registration-role-options">
          {([
            ["consumer", "Regular User", "Browse, save listings, and contact agents."],
            ["agent", "Agent", "Submit an application to the brokerage that referred you."],
            ["broker", "Broker", "Register your brokerage for ProperAP review and activation."],
          ] as const).map(([value, label, description]) => (
            <label className={`registration-role-option ${role === value ? "selected" : ""}`} key={value}>
              <input type="radio" checked={role === value} onChange={() => setRole(value)} />
              <span><strong>{label}</strong><small>{description}</small></span>
            </label>
          ))}
        </div>
      </fieldset>
      <label><span>First name</span><input name="firstName" autoComplete="given-name" minLength={1} maxLength={80} required /></label>
      <label><span>Last name</span><input name="lastName" autoComplete="family-name" minLength={1} maxLength={80} required /></label>
      <label className="full"><span>Email</span><input name="email" type="email" autoComplete="email" maxLength={320} required /></label>
      {role !== "consumer" && <>
        <label><span>Contact number</span><input name="contactPhone" type="tel" autoComplete="tel" minLength={7} maxLength={30} required /></label>
        <label><span>Business address</span><input name="contactAddress" autoComplete="street-address" minLength={8} maxLength={500} required /></label>
        {role === "agent" ? <label className="full"><span>Brokerage that referred you</span><select name="brokerageId" required defaultValue=""><option value="" disabled>Select your brokerage</option>{brokerages.map((brokerage) => <option value={brokerage.id} key={brokerage.id}>{brokerage.display_name}</option>)}</select></label> : <label className="full"><span>Brokerage name</span><input name="brokerageName" minLength={2} maxLength={160} required placeholder="Your brokerage company name" /></label>}
        <p className="registration-notice full"><strong>Professional accounts start inactive.</strong> ProperAP must approve the registration and confirm activation or payment before professional workspace access is enabled.</p>
      </>}
      <label><span>Password</span><input name="password" type="password" autoComplete="new-password" minLength={10} maxLength={128} required /></label>
      <label><span>Confirm password</span><input name="confirmPassword" type="password" autoComplete="new-password" minLength={10} maxLength={128} required /></label>
      <label className="check-row full"><input name="privacyAccepted" type="checkbox" required /> I agree to the privacy notice and account terms for this pilot.</label>
      <button className="solid-button full" type="submit">{role === "consumer" ? "Create free account" : "Submit professional registration"}</button>
    </form>
  );
}
