import { Suspense } from "react";
import { redirect } from "next/navigation";
import { LoginForm } from "@/components/login-form";
import { Skeleton } from "@/components/ui/skeleton";
import { hasSession } from "@/lib/auth";
import { safeNextPath } from "@/lib/safe-next";

export default async function Login({
  searchParams,
}: {
  searchParams: Promise<{ next?: string | string[] }>;
}) {
  if (await hasSession()) {
    const { next } = await searchParams;
    redirect(safeNextPath(next));
  }

  return (
    <main className="grid min-h-dvh place-items-center px-4 py-12">
      <div className="flex w-full flex-col items-center gap-6">
        <div className="text-center">
          <p className="text-xs font-semibold uppercase tracking-[.18em] text-muted-foreground">
            Brew → taste → adjust
          </p>
          <h1 className="mt-2 text-4xl font-semibold tracking-tight">
            DripWatch
          </h1>
        </div>
        <Suspense fallback={<Skeleton className="h-80 w-full max-w-sm" />}>
          <LoginForm />
        </Suspense>
      </div>
    </main>
  );
}
