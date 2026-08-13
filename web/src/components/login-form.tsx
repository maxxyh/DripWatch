"use client";

import { useState } from "react";
import Image from "next/image";
import { useSearchParams } from "next/navigation";
import { Button } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Field,
  FieldError,
  FieldGroup,
  FieldLabel,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";

export function LoginForm() {
  const params = useSearchParams();
  const [error, setError] = useState("");
  const [busy, setBusy] = useState(false);

  async function submit(event: React.FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError("");
    const passcode = new FormData(event.currentTarget).get("passcode");
    const result = await fetch("/api/auth/login", {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ passcode }),
    });
    setBusy(false);
    if (!result.ok) {
      setError("That passcode does not match.");
      return;
    }
    const next = params.get("next");
    location.replace(
      next?.startsWith("/") && !next.startsWith("//") ? next : "/",
    );
  }

  return (
    <Card className="w-full max-w-sm">
      <CardHeader>
        <Image
          src="/icons/icon-192.png"
          alt="DripWatch"
          width={44}
          height={44}
          className="mb-2 rounded-xl"
        />
        <CardTitle>Open the shared notebook</CardTitle>
        <CardDescription>
          Enter the DripWatch passcode your team uses.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <form onSubmit={submit}>
          <FieldGroup>
            <Field data-invalid={!!error}>
              <FieldLabel htmlFor="passcode">Shared passcode</FieldLabel>
              <Input
                id="passcode"
                name="passcode"
                type="password"
                autoComplete="current-password"
                autoFocus
                required
                aria-invalid={!!error}
              />
              {error && <FieldError>{error}</FieldError>}
            </Field>
            <Button type="submit" disabled={busy}>
              {busy ? "Opening…" : "Open DripWatch"}
            </Button>
          </FieldGroup>
        </form>
      </CardContent>
    </Card>
  );
}
