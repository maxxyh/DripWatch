"use client";
import { useEffect } from "react";
export function PwaClient() {
  useEffect(() => {
    const yes = () => {
        location.reload();
      };
    addEventListener("online", yes);
    if ("serviceWorker" in navigator) {
      if (process.env.NODE_ENV === "production") {
        navigator.serviceWorker.register("/sw.js").then(async () => {
          const registration = await navigator.serviceWorker.ready;
          const response = await fetch("/api/auth/session", {
            cache: "no-store",
          });
          if (!response.ok) {
            localStorage.removeItem("dripwatch-notebook-v1");
            localStorage.removeItem("dripwatch-session-lease");
            registration.active?.postMessage({
              type: "CLEAR_PROTECTED_DATA",
            });
            if (location.pathname !== "/login") location.replace("/login");
            return;
          }
          const lease = (await response.json()) as {
            cacheScope: string;
            expiresAt: number;
          };
          localStorage.setItem(
            "dripwatch-session-lease",
            JSON.stringify(lease),
          );
          registration.active?.postMessage({
            type: "SET_SESSION_LEASE",
            lease,
          });
        });
      } else {
        navigator.serviceWorker
          .getRegistrations()
          .then((items) => items.forEach((item) => item.unregister()));
        caches
          .keys()
          .then((keys) =>
            keys
              .filter((key) => key.startsWith("dripwatch-"))
              .forEach((key) => caches.delete(key)),
          );
      }
    }
    return () => {
      removeEventListener("online", yes);
    };
  }, []);
  return null;
}
