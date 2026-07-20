export type BrokeragePlanLimits = {
  label: string;
  agentLimit: number | null;
  staffLimit: number | null;
};

const brokeragePlanLimits: Record<string, BrokeragePlanLimits> = {
  brokerage_20: { label: "Broker Core", agentLimit: 20, staffLimit: 5 },
  brokerage_growth: { label: "Broker Growth", agentLimit: 75, staffLimit: 15 },
};

export function getBrokeragePlanLimits(planKey?: string | null): BrokeragePlanLimits {
  if (planKey && brokeragePlanLimits[planKey]) return brokeragePlanLimits[planKey];
  return { label: "No active brokerage plan", agentLimit: 0, staffLimit: 0 };
}
