export type ExchangeRateSnapshot = {
  jmd_per_usd: number | string;
  cad_per_usd: number | string;
  gbp_per_usd: number | string;
  provider_updated_at: string;
};

export type DisplayCurrency = "JMD" | "USD" | "CAD" | "GBP";

export const DISPLAY_CURRENCIES: DisplayCurrency[] = ["JMD", "USD", "CAD", "GBP"];

export function isDisplayCurrency(value: string): value is DisplayCurrency {
  return DISPLAY_CURRENCIES.includes(value as DisplayCurrency);
}

export function convertJmdToCurrency(jmdAmount: number, currency: DisplayCurrency, rates: ExchangeRateSnapshot | null) {
  if (currency === "JMD" || !rates) return jmdAmount;
  const usd = jmdAmount / Number(rates.jmd_per_usd);
  if (currency === "USD") return usd;
  return currency === "CAD" ? usd * Number(rates.cad_per_usd) : usd * Number(rates.gbp_per_usd);
}

export function convertCurrencyToJmd(amount: number, currency: DisplayCurrency, rates: ExchangeRateSnapshot | null) {
  if (currency === "JMD" || !rates) return amount;
  if (currency === "USD") return amount * Number(rates.jmd_per_usd);
  if (currency === "CAD") return (amount / Number(rates.cad_per_usd)) * Number(rates.jmd_per_usd);
  return (amount / Number(rates.gbp_per_usd)) * Number(rates.jmd_per_usd);
}

export function formatCurrencyAmount(amount: number, currency: DisplayCurrency, compact = false) {
  if (currency === "JMD") return `J$${new Intl.NumberFormat("en-JM", { maximumFractionDigits: 0, ...(compact ? { notation: "compact" as const } : {}) }).format(amount)}`;
  return new Intl.NumberFormat("en-JM", { style: "currency", currency, maximumFractionDigits: 0, ...(compact ? { notation: "compact" as const } : {}) }).format(amount);
}
