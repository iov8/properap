"use client";

import { useEffect } from "react";
import { createClient } from "@/lib/supabase/client";

type LiveMailboxTable = "inquiries" | "notifications";

export function useLiveMailbox(table: LiveMailboxTable, onChange: () => void) {
  useEffect(() => {
    const supabase = createClient();
    let refreshTimer: number | undefined;

    const scheduleRefresh = () => {
      window.clearTimeout(refreshTimer);
      refreshTimer = window.setTimeout(onChange, 150);
    };

    const channel = supabase
      .channel(`properap-${table}-${crypto.randomUUID()}`)
      .on("postgres_changes", { event: "*", schema: "public", table }, scheduleRefresh)
      .subscribe((status) => {
        if (status === "SUBSCRIBED") scheduleRefresh();
      });

    const fallbackInterval = window.setInterval(scheduleRefresh, 15_000);
    const handleFocus = () => scheduleRefresh();
    const handleVisibility = () => {
      if (document.visibilityState === "visible") scheduleRefresh();
    };
    window.addEventListener("focus", handleFocus);
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      window.clearTimeout(refreshTimer);
      window.clearInterval(fallbackInterval);
      window.removeEventListener("focus", handleFocus);
      document.removeEventListener("visibilitychange", handleVisibility);
      void supabase.removeChannel(channel);
    };
  }, [onChange, table]);
}
