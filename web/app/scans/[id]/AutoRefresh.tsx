"use client";

import { useEffect } from "react";

export default function AutoRefresh({ intervalMs = 3000 }: { intervalMs?: number }) {
  useEffect(() => {
    const t = setTimeout(() => location.reload(), intervalMs);
    return () => clearTimeout(t);
  }, [intervalMs]);
  return null;
}
