"use client";

import { useState } from "react";
import { convertJmdToCurrency, DISPLAY_CURRENCIES, formatCurrencyAmount, type DisplayCurrency, type ExchangeRateSnapshot } from "@/lib/currency-conversions";

const priceOptions = [0, 1_000_000, 5_000_000, 10_000_000, 25_000_000, 50_000_000, 100_000_000, 250_000_000, 500_000_000];

export function CurrencyPriceRangeFields({ rates, initialCurrency = "JMD" }: { rates: ExchangeRateSnapshot | null; initialCurrency?: DisplayCurrency }) {
  const availableCurrencies = rates ? DISPLAY_CURRENCIES : ["JMD"];
  const [currency, setCurrency] = useState<DisplayCurrency>(availableCurrencies.includes(initialCurrency) ? initialCurrency : "JMD");
  const [minimumJmd, setMinimumJmd] = useState(0);
  const [maximumJmd, setMaximumJmd] = useState(500_000_000);
  const toValue = (amount: number) => String(Math.round(convertJmdToCurrency(amount, currency, rates)));
  const fromValue = (value: string) => priceOptions.find((amount) => toValue(amount) === value) ?? 0;

  return <>
    <label><span>Currency</span><select name="currency" value={currency} onChange={(event) => setCurrency(event.target.value as DisplayCurrency)}>{availableCurrencies.map((item) => <option key={item} value={item}>{item}</option>)}</select></label>
    <label><span>Min price</span><select name="minPrice" value={toValue(minimumJmd)} onChange={(event) => setMinimumJmd(fromValue(event.target.value))}>{priceOptions.map((amount) => <option key={amount} value={toValue(amount)}>{formatCurrencyAmount(convertJmdToCurrency(amount, currency, rates), currency, true)}</option>)}</select></label>
    <label><span>Max price</span><select name="maxPrice" value={maximumJmd === 500_000_000 ? `${toValue(maximumJmd)}+` : toValue(maximumJmd)} onChange={(event) => setMaximumJmd(event.target.value.endsWith("+") ? 500_000_000 : fromValue(event.target.value))}>{priceOptions.slice(1).map((amount) => <option key={amount} value={amount === 500_000_000 ? `${toValue(amount)}+` : toValue(amount)}>{formatCurrencyAmount(convertJmdToCurrency(amount, currency, rates), currency, true)}{amount === 500_000_000 ? "+" : ""}</option>)}</select></label>
  </>;
}
