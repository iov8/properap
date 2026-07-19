"use client";

import { useState } from "react";
import { DISPLAY_CURRENCIES, formatCurrencyAmount, type DisplayCurrency, type ExchangeRateSnapshot } from "@/lib/currency-conversions";

const priceOptions: Record<DisplayCurrency, number[]> = {
  JMD: [0, 1_000_000, 5_000_000, 10_000_000, 25_000_000, 50_000_000, 100_000_000, 250_000_000, 500_000_000],
  USD: [0, 50_000, 100_000, 125_000, 150_000, 175_000, 200_000, 250_000, 300_000, 400_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000, 5_000_000],
  CAD: [0, 75_000, 100_000, 125_000, 150_000, 175_000, 200_000, 250_000, 300_000, 400_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000, 5_000_000],
  GBP: [0, 50_000, 75_000, 100_000, 125_000, 150_000, 175_000, 200_000, 250_000, 300_000, 400_000, 500_000, 750_000, 1_000_000, 1_500_000, 2_000_000, 3_000_000],
};

export function CurrencyPriceRangeFields({ rates, initialCurrency = "JMD" }: { rates: ExchangeRateSnapshot | null; initialCurrency?: DisplayCurrency }) {
  const availableCurrencies = rates ? DISPLAY_CURRENCIES : ["JMD"];
  const [currency, setCurrency] = useState<DisplayCurrency>(availableCurrencies.includes(initialCurrency) ? initialCurrency : "JMD");
  const [minimum, setMinimum] = useState(0);
  const [maximum, setMaximum] = useState(() => priceOptions[currency].at(-1) ?? 0);
  const options = priceOptions[currency];
  const maximumOption = options.at(-1) ?? 0;
  const changeCurrency = (nextCurrency: DisplayCurrency) => {
    setCurrency(nextCurrency);
    setMinimum(0);
    setMaximum(priceOptions[nextCurrency].at(-1) ?? 0);
  };

  return <>
    <label><span>Currency</span><select name="currency" value={currency} onChange={(event) => changeCurrency(event.target.value as DisplayCurrency)}>{availableCurrencies.map((item) => <option key={item} value={item}>{item}</option>)}</select></label>
    <label><span>Min price</span><select name="minPrice" value={minimum} onChange={(event) => setMinimum(Number(event.target.value))}>{options.map((amount) => <option key={amount} value={amount}>{formatCurrencyAmount(amount, currency)}</option>)}</select></label>
    <label><span>Max price</span><select name="maxPrice" value={maximum === maximumOption ? `${maximumOption}+` : maximum} onChange={(event) => setMaximum(event.target.value.endsWith("+") ? maximumOption : Number(event.target.value))}>{options.slice(1).map((amount) => <option key={amount} value={amount === maximumOption ? `${amount}+` : amount}>{formatCurrencyAmount(amount, currency)}{amount === maximumOption ? "+" : ""}</option>)}</select></label>
  </>;
}
