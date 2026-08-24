"use client";
import Image from "next/image";
import Link from "next/link";
import dynamic from "next/dynamic";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  ArrowDown,
  ArrowUp,
  ChevronRight,
  Cloud,
  CloudOff,
  Coffee,
  ImageIcon,
  LogOut,
  Plus,
  RefreshCw,
  Search,
  Sparkles,
} from "lucide-react";
import { Alert, AlertDescription, AlertTitle } from "@/components/ui/alert";
import { Badge } from "@/components/ui/badge";
import { Button, buttonVariants } from "@/components/ui/button";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Empty,
  EmptyContent,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty";
import { Input } from "@/components/ui/input";
import {
  Select,
  SelectContent,
  SelectItem,
  SelectTrigger,
  SelectValue,
} from "@/components/ui/select";
import { Skeleton } from "@/components/ui/skeleton";
import { ThemeSelect } from "@/components/theme-select";
import { cn } from "@/lib/utils";
import type { BeanRow, Notebook } from "@/lib/domain";
import { photoUrl, pricePerGramSGD, pricePerGramTextSGD } from "@/lib/domain";

const BeanDetail = dynamic(() => import("./bean-detail"));

const SNAPSHOT = "dripwatch-notebook-v1";
const SESSION_LEASE = "dripwatch-session-lease";
function readCachedSnapshot(): Notebook | null {
  try {
    const cached = localStorage.getItem(SNAPSHOT);
    if (!cached) return null;
    const lease = JSON.parse(
      localStorage.getItem(SESSION_LEASE) || "null",
    ) as { expiresAt?: number } | null;
    if (!lease?.expiresAt || lease.expiresAt <= Date.now()) return null;
    return JSON.parse(cached) as Notebook;
  } catch {
    // Corrupted or incompatible cache entry: never let it block the real
    // fetch, and clear it so it doesn't keep failing on every call.
    localStorage.removeItem(SNAPSHOT);
    localStorage.removeItem(SESSION_LEASE);
    return null;
  }
}
function useNotebook() {
  const [data, setData] = useState<Notebook | null>(null),
    [offline, setOffline] = useState(false),
    // True only for the brief window between painting a cached snapshot and
    // the background refresh() confirming it: keeps mutations disabled
    // without claiming we're offline when we're not.
    [revalidating, setRevalidating] = useState(false),
    [error, setError] = useState("");
  const paintedCache = useRef(false);
  async function refresh() {
    if (!paintedCache.current) {
      paintedCache.current = true;
      const cached = readCachedSnapshot();
      if (cached) {
        setData(cached);
        setRevalidating(true);
      }
    }
    try {
      const response = await fetch("/api/notebook", { cache: "no-store" });
      if (response.status === 401 || response.status === 403) {
        localStorage.removeItem(SNAPSHOT);
        localStorage.removeItem(SESSION_LEASE);
        navigator.serviceWorker?.controller?.postMessage({
          type: "CLEAR_PROTECTED_DATA",
        });
        location.replace("/login");
        return;
      }
      if (!response.ok)
        throw new Error((await response.json()).error || "Could not refresh");
      const next = (await response.json()) as Notebook;
      setData(next);
      setOffline(
        response.headers.get("x-dripwatch-offline-fallback") === "true",
      );
      setRevalidating(false);
      localStorage.setItem(SNAPSHOT, JSON.stringify(next));
    } catch (e) {
      const cached = readCachedSnapshot();
      setRevalidating(false);
      if (cached) {
        setData(cached);
        setOffline(true);
      } else {
        localStorage.removeItem(SNAPSHOT);
        setError(e instanceof Error ? e.message : "Could not load notebook");
      }
    }
  }
  useEffect(() => {
    const timeout = setTimeout(refresh, 0);
    return () => clearTimeout(timeout);
  }, []);
  return { data, offline, revalidating, error, refresh, setData };
}
export function NotebookApp({
  view = "shelf",
  id,
}: {
  view?: "shelf" | "bean";
  id?: string;
}) {
  const notebook = useNotebook();
  if (!notebook.data && !notebook.error) return <LoadingShelf />;
  if (notebook.error && !notebook.data)
    return (
      <main className="mx-auto w-full max-w-2xl px-4 py-20">
        <Alert variant="destructive">
          <CloudOff />
          <AlertTitle>Notebook unavailable</AlertTitle>
          <AlertDescription>
            {notebook.error}. Check the server environment and connection.
          </AlertDescription>
        </Alert>
      </main>
    );
  // Read-only while genuinely offline, and also for the brief window where
  // we've painted a cached snapshot but haven't heard back from the
  // background refresh yet — without flashing the offline banner for it.
  const readOnly = notebook.offline || notebook.revalidating;
  return (
    <div className="min-h-dvh pb-[max(1.5rem,env(safe-area-inset-bottom))]">
      <Header offline={notebook.offline} refresh={notebook.refresh} />
      {notebook.offline && (
        <div
          role="status"
          className="sticky top-14 z-10 bg-foreground px-4 py-2 text-center text-sm font-medium text-background"
        >
          Offline snapshot · viewing only
        </div>
      )}
      {view === "bean" && id ? (
        <BeanDetail
          data={notebook.data!}
          beanId={id}
          offline={readOnly}
          refresh={notebook.refresh}
        />
      ) : (
        <Shelf data={notebook.data!} offline={readOnly} />
      )}
    </div>
  );
}
function Header({
  offline,
  refresh,
}: {
  offline: boolean;
  refresh: () => Promise<void>;
}) {
  const router = useRouter();
  async function logout() {
    try {
      await fetch("/api/auth/logout", { method: "POST" });
    } finally {
      localStorage.removeItem(SNAPSHOT);
      localStorage.removeItem(SESSION_LEASE);
      if ("caches" in window)
        for (const key of await caches.keys())
          if (key.startsWith("dripwatch-protected")) await caches.delete(key);
      navigator.serviceWorker?.controller?.postMessage({
        type: "CLEAR_PROTECTED_DATA",
      });
      router.replace("/login");
      router.refresh();
    }
  }
  return (
    <header className="sticky top-0 z-20 border-b bg-background/90 backdrop-blur">
      <div className="mx-auto flex h-14 max-w-7xl items-center gap-3 px-4">
        <Link
          href="/"
          className="flex min-h-11 items-center gap-2 font-semibold tracking-tight"
        >
          <Image
            src="/icons/icon-192.png"
            alt=""
            width={28}
            height={28}
            className="rounded-md"
            aria-hidden
          />
          DripWatch
        </Link>
        <div className="ml-auto flex items-center gap-1">
          <Button
            variant="ghost"
            size="icon"
            onClick={refresh}
            aria-label="Refresh notebook"
          >
            <RefreshCw />
          </Button>
          <ThemeSelect />
          <Button
            variant="ghost"
            size="icon"
            onClick={logout}
            aria-label="Log out"
          >
            <LogOut />
          </Button>
          {offline ? (
            <CloudOff aria-label="Offline" className="text-muted-foreground" />
          ) : (
            <Cloud
              aria-label="Online and refreshed"
              className="text-positive"
            />
          )}
        </div>
      </div>
    </header>
  );
}
type SortField = "updated" | "price" | "name" | "roast";

function defaultSortDirection(field: SortField): "asc" | "desc" {
  return field === "price" || field === "name" ? "asc" : "desc";
}

const sortLabels: Record<SortField, string> = {
  updated: "Recently updated",
  price: "Price",
  name: "Name",
  roast: "Roast date",
};

type MethodFilter = "all" | "pourover" | "espresso";

const methodLabels: Record<MethodFilter, string> = {
  all: "All",
  pourover: "Pourover",
  espresso: "Espresso",
};

function compareBeans(
  a: BeanRow,
  b: BeanRow,
  field: SortField,
  dir: "asc" | "desc",
): number {
  let cmp = 0;
  switch (field) {
    case "price":
      if (a.price_sgd == null && b.price_sgd == null) cmp = 0;
      else if (a.price_sgd == null) cmp = 1;
      else if (b.price_sgd == null) cmp = -1;
      else cmp = a.price_sgd - b.price_sgd;
      break;
    case "name":
      cmp = (a.name || "").localeCompare(b.name || "");
      break;
    case "roast": {
      const aNull = a.roast_date == null;
      const bNull = b.roast_date == null;
      if (aNull && bNull) cmp = 0;
      else if (aNull) cmp = 1;
      else if (bNull) cmp = -1;
      else cmp = a.roast_date!.localeCompare(b.roast_date!);
      break;
    }
    case "updated":
    default:
      cmp = a.updated_at.localeCompare(b.updated_at);
      break;
  }
  return dir === "asc" ? cmp : -cmp;
}

function Shelf({ data, offline }: { data: Notebook; offline: boolean }) {
  const [query, setQuery] = useState("");
  const [sortBy, setSortBy] = useState<SortField>("updated");
  const [sortDir, setSortDir] = useState<"asc" | "desc">("desc");
  const [methodFilter, setMethodFilter] = useState<MethodFilter>("all");

  const normalizedQuery = query.trim().toLowerCase();
  const active = data.beans
    .filter((b) => {
      if (b.deleted_at) return false;
      if (normalizedQuery && !b.name.toLowerCase().includes(normalizedQuery))
        return false;
      if (methodFilter === "all") return true;
      return data.brews.some(
        (brew) =>
          !brew.deleted_at &&
          brew.bean_id === b.id &&
          brew.method_raw === methodFilter,
      );
    })
    .sort((a, b) => compareBeans(a, b, sortBy, sortDir));
  const fresh = active.filter((b) => !b.finished_at);
  const finished = active.filter((b) => b.finished_at);

  return (
    <main className="mx-auto w-full max-w-7xl px-4 py-6 md:px-8">
      <div className="mb-6 flex items-end justify-between gap-4">
        <div>
          <p className="overline">Shared coffee notebook</p>
          <h1 className="text-3xl font-semibold tracking-tight sm:text-4xl">
            Shelf
          </h1>
        </div>
        {offline ? (
          <Button disabled>
            <Plus data-icon="inline-start" />
            Add bean
          </Button>
        ) : (
          <Link href="/beans/new" className={buttonVariants()}>
            <Plus data-icon="inline-start" />
            Add bean
          </Link>
        )}
      </div>

      <div className="mb-6 flex flex-col gap-3 sm:flex-row sm:items-center sm:justify-between">
        <div className="relative flex-1 sm:max-w-xs">
          <Search
            aria-hidden
            className="absolute left-2.5 top-1/2 size-4 -translate-y-1/2 text-muted-foreground"
          />
          <Input
            type="search"
            placeholder="Search beans by name..."
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            className="pl-9"
            aria-label="Search beans by name"
          />
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm text-muted-foreground" id="sort-label">
            Sort by
          </span>
          <Select
            value={sortBy}
            onValueChange={(value) => {
              const next = value as SortField;
              setSortBy(next);
              setSortDir(defaultSortDirection(next));
            }}
          >
            <SelectTrigger aria-labelledby="sort-label" className="w-44">
              <SelectValue>
                {(value: SortField) => sortLabels[value]}
              </SelectValue>
            </SelectTrigger>
            <SelectContent>
              <SelectItem value="updated">Recently updated</SelectItem>
              <SelectItem value="price">Price</SelectItem>
              <SelectItem value="name">Name</SelectItem>
              <SelectItem value="roast">Roast date</SelectItem>
            </SelectContent>
          </Select>
          <Button
            variant="ghost"
            size="icon"
            aria-label={sortDir === "asc" ? "Ascending" : "Descending"}
            onClick={() => setSortDir((d) => (d === "asc" ? "desc" : "asc"))}
          >
            {sortDir === "asc" ? <ArrowUp /> : <ArrowDown />}
          </Button>
        </div>
      </div>

      <div
        className="mb-6 flex flex-wrap gap-2"
        role="group"
        aria-label="Filter by brew method"
      >
        {(["all", "pourover", "espresso"] as MethodFilter[]).map((value) => (
          <Button
            key={value}
            size="sm"
            aria-pressed={methodFilter === value}
            onClick={() => setMethodFilter(value)}
            className={cn(
              buttonVariants({
                variant: methodFilter === value ? "default" : "outline",
                size: "xl",
              }),
              "rounded-full",
            )}
          >
            {methodLabels[value]}
          </Button>
        ))}
      </div>

      {fresh.length ? (
        <Masonry beans={fresh} data={data} />
      ) : normalizedQuery || methodFilter !== "all" ? (
        <p className="text-sm text-muted-foreground">
          No active beans match your filters.
        </p>
      ) : (
        <Empty className="border">
          <EmptyHeader>
            <EmptyMedia variant="icon">
              <Coffee />
            </EmptyMedia>
            <EmptyTitle>Your shelf is empty</EmptyTitle>
            <EmptyDescription>
              Add a coffee bag to start the brew–taste–adjust loop.
            </EmptyDescription>
          </EmptyHeader>
          <EmptyContent>
            {offline ? (
              <Button disabled>Add a bean</Button>
            ) : (
              <Link href="/beans/new" className={buttonVariants()}>
                Add a bean
              </Link>
            )}
          </EmptyContent>
        </Empty>
      )}
      {finished.length > 0 && (
        <section className="mt-10 opacity-65">
          <div className="mb-4 flex items-baseline justify-between">
            <h2 className="text-xl font-semibold">Finished</h2>
            <span className="text-sm text-muted-foreground">
              {finished.length}
            </span>
          </div>
          <Masonry beans={finished} data={data} />
        </section>
      )}
    </main>
  );
}
function Masonry({ beans, data }: { beans: BeanRow[]; data: Notebook }) {
  return (
    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4 sm:gap-4">
      {beans.map((bean, index) => (
        <BeanCard
          key={bean.id}
          bean={bean}
          data={data}
          priority={index < 2}
        />
      ))}
    </div>
  );
}
function BeanCard({
  bean,
  data,
  priority = false,
}: {
  bean: BeanRow;
  data: Notebook;
  priority?: boolean;
}) {
  const photos = data.beanPhotos
      .filter((p) => !p.deleted_at && p.bean_id === bean.id)
      .sort((a, b) => a.order - b.order),
    hero = photoUrl(
      "bean-photos",
      photos.find((photo) => photo.remote_path)?.remote_path ?? null,
    ),
    count = data.brews.filter(
      (b) => !b.deleted_at && b.bean_id === bean.id,
    ).length,
    pricePerGram = pricePerGramSGD(bean.price_sgd, bean.bag_size_grams),
    notes = (bean.roaster_notes ?? "")
      .split(",")
      .map((x) => x.trim())
      .filter(Boolean)
      .slice(0, 3);
  return (
    <Link
      href={`/beans/${bean.id}`}
      className="group block h-full rounded-xl focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-ring"
    >
      <Card className="h-full overflow-hidden py-0 transition-transform motion-safe:group-hover:-translate-y-0.5">
        <div className="relative aspect-[4/3] bg-muted">
          {hero ? (
            <Image
              src={hero}
              alt={`${bean.name} coffee bag`}
              fill
              sizes="(max-width:640px) 45vw, 25vw"
              className="object-cover"
              loading={priority ? "eager" : "lazy"}
            />
          ) : (
            <div className="grid h-full place-items-center">
              <ImageIcon className="text-muted-foreground" aria-hidden />
            </div>
          )}
          {photos.length > 1 && (
            <Badge className="absolute right-2 top-2" variant="secondary">
              {photos.length} photos
            </Badge>
          )}
        </div>
        <CardHeader className="gap-1 pt-4">
          <CardTitle className="text-base leading-tight">
            {bean.name || "Untitled bean"}
          </CardTitle>
          {bean.roaster_name && (
            <CardDescription>{bean.roaster_name}</CardDescription>
          )}
        </CardHeader>
        <CardContent className="flex flex-col gap-3 pb-4">
          <p className="text-xs text-muted-foreground">
            {[bean.process, bean.country].filter(Boolean).join(" · ") ||
              "Roaster facts not added"}
          </p>
          {notes.length > 0 && (
            <div className="flex flex-wrap gap-1">
              {notes.map((n) => (
                <Badge key={n} variant="outline">
                  <Sparkles aria-hidden />
                  {n}
                </Badge>
              ))}
            </div>
          )}
          <div className="flex items-end justify-between gap-2 text-xs text-muted-foreground">
            <div className="flex min-w-0 flex-col gap-1">
              {pricePerGram !== null && (
                <span className="font-semibold text-primary">
                  {pricePerGramTextSGD(pricePerGram)}
                </span>
              )}
              <span>
                {count} brew{count === 1 ? "" : "s"} together
              </span>
            </div>
            <ChevronRight aria-hidden />
          </div>
        </CardContent>
      </Card>
    </Link>
  );
}
function LoadingShelf() {
  return (
    <main className="mx-auto w-full max-w-7xl px-4 py-20">
      <div className="grid grid-cols-2 gap-3 sm:grid-cols-3 lg:grid-cols-4">
        {Array.from({ length: 8 }, (_, i) => (
          <Skeleton key={i} className="h-64 rounded-xl" />
        ))}
      </div>
    </main>
  );
}
