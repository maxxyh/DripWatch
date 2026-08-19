"use client";
import Image from "next/image";
import Link from "next/link";
import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import {
  Archive,
  ArchiveRestore,
  ArrowLeft,
  Coffee,
  Copy,
  Ellipsis,
  ImageIcon,
  Trash2,
  X,
} from "lucide-react";
import { toast } from "sonner";
import {
  AlertDialog,
  AlertDialogAction,
  AlertDialogCancel,
  AlertDialogContent,
  AlertDialogDescription,
  AlertDialogFooter,
  AlertDialogHeader,
  AlertDialogTitle,
  AlertDialogTrigger,
} from "@/components/ui/alert-dialog";
import { Badge } from "@/components/ui/badge";
import { Button, buttonVariants } from "@/components/ui/button";
import { cn } from "@/lib/utils";
import {
  Card,
  CardContent,
  CardDescription,
  CardHeader,
  CardTitle,
} from "@/components/ui/card";
import {
  Empty,
  EmptyDescription,
  EmptyHeader,
  EmptyMedia,
  EmptyTitle,
} from "@/components/ui/empty";
import type { BeanRow, BrewRow, Notebook, Recipe } from "@/lib/domain";
import {
  brewDiff,
  brewMarkdown,
  photoUrl,
  singlePendingPlanPatch,
} from "@/lib/domain";
import { mutate } from "@/lib/client-mutations";
import { RecipeEditor } from "@/components/recipe-editor";
import {
  ChangeChips,
  RecipeReadout,
  RoasterNoteChips,
} from "@/components/recipe-readout";
import { PhotoViewer, type PreviewPhoto } from "@/components/photo-viewer";

export default function BeanDetail({
  data,
  beanId,
  offline,
  refresh,
}: {
  data: Notebook;
  beanId: string;
  offline: boolean;
  refresh: () => Promise<void>;
}) {
  const router = useRouter();
  const [working, setWorking] = useState(false);
  const bean = data.beans.find((b) => b.id === beanId && !b.deleted_at);
  if (!bean)
    return (
      <main className="mx-auto w-full max-w-3xl px-4 py-16">
        <Empty>
          <EmptyHeader>
            <EmptyTitle>Bean not found</EmptyTitle>
            <EmptyDescription>
              It may have been removed from the shared notebook.
            </EmptyDescription>
          </EmptyHeader>
        </Empty>
      </main>
    );
  const brews = data.brews
    .filter((b) => !b.deleted_at && b.bean_id === bean.id)
    .sort((a, b) => b.brewed_at.localeCompare(a.brewed_at));
  const photos = data.beanPhotos
    .filter((p) => !p.deleted_at && p.bean_id === bean.id)
    .sort((a, b) => a.order - b.order);
  const pendingPlan = bean.pending_next_pourover
    ? { method: "pourover" as const, recipe: bean.pending_next_pourover }
    : bean.pending_next_espresso
      ? { method: "espresso" as const, recipe: bean.pending_next_espresso }
      : null;
  async function toggleFinished() {
    if (!bean || working) return;
    setWorking(true);
    try {
      await mutate(
        "beans",
        {
          id: bean.id,
          finished_at: bean.finished_at ? null : new Date().toISOString(),
        },
        bean.updated_at,
      );
      toast.success(bean.finished_at ? "Bean reopened" : "Bean finished");
      await refresh();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not update bean",
      );
    } finally {
      setWorking(false);
    }
  }
  async function deleteBean() {
    if (!bean || working) return;
    setWorking(true);
    const deletedAt = new Date().toISOString();
    try {
      for (const brew of brews)
        await mutate(
          "brews",
          { id: brew.id, deleted_at: deletedAt },
          brew.updated_at,
        );
      for (const photo of photos)
        await mutate(
          "bean_photos",
          { id: photo.id, deleted_at: deletedAt },
          photo.updated_at,
        );
      await mutate(
        "beans",
        { id: bean.id, deleted_at: deletedAt },
        bean.updated_at,
      );
      toast.success("Bean removed from the shelf");
      router.replace("/");
      router.refresh();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not remove bean",
      );
      await refresh();
    } finally {
      setWorking(false);
    }
  }
  return (
    <main className="mx-auto w-full max-w-6xl px-4 py-5 md:px-8">
      <div className="mb-4 flex flex-wrap items-center justify-between gap-2">
        <Link href="/" className={buttonVariants({ variant: "ghost" })}>
          <ArrowLeft data-icon="inline-start" />
          Shelf
        </Link>
        <div className="flex flex-wrap items-center justify-end gap-2">
          <Button
            variant="outline"
            onClick={toggleFinished}
            disabled={offline || working}
          >
            {bean.finished_at ? <ArchiveRestore /> : <Archive />}
            {bean.finished_at ? "Reopen" : "Finish"}
          </Button>
          <Link
            href={`/beans/${bean.id}/edit`}
            aria-disabled={offline || working}
            tabIndex={offline || working ? -1 : undefined}
            onClick={(event) => {
              if (offline || working) event.preventDefault();
            }}
            className={cn(
              buttonVariants({ variant: "outline" }),
              (offline || working) && "pointer-events-none opacity-50",
            )}
          >
            Edit bean
          </Link>
          <AlertDialog>
            <AlertDialogTrigger
              render={
                <Button
                  variant="ghost"
                  size="icon"
                  disabled={offline || working}
                  aria-label="Delete bean"
                />
              }
            >
              <Trash2 />
            </AlertDialogTrigger>
            <AlertDialogContent>
              <AlertDialogHeader>
                <AlertDialogTitle>Delete this bean?</AlertDialogTitle>
                <AlertDialogDescription>
                  This removes the bean, its brew history, and its photos from
                  the shared shelf. Synced records are retained as soft-deleted
                  rows.
                </AlertDialogDescription>
              </AlertDialogHeader>
              <AlertDialogFooter>
                <AlertDialogCancel>Cancel</AlertDialogCancel>
                <AlertDialogAction
                  variant="destructive"
                  onClick={deleteBean}
                  disabled={working}
                >
                  Delete bean
                </AlertDialogAction>
              </AlertDialogFooter>
            </AlertDialogContent>
          </AlertDialog>
        </div>
      </div>
      <div className="grid gap-6 lg:grid-cols-[minmax(0,1.05fr)_minmax(21rem,.95fr)]">
        <section className="flex flex-col gap-4">
          <CharacterCard bean={bean} photos={photos} />
          {pendingPlan && (
            <PlanCard
              method={pendingPlan.method}
              recipe={pendingPlan.recipe}
              prior={
                brews.find((b) => b.method_raw === pendingPlan.method)?.recipe
              }
              bean={bean}
              data={data}
              offline={offline}
              refresh={refresh}
            />
          )}
          <div className="grid grid-cols-2 gap-3">
            <Link
              href={`/beans/${bean.id}/brews/new?method=pourover`}
              aria-disabled={offline}
              tabIndex={offline ? -1 : undefined}
              onClick={(event) => {
                if (offline) event.preventDefault();
              }}
              className={cn(
                buttonVariants({ size: "lg" }),
                offline && "pointer-events-none opacity-50",
              )}
            >
              Pourover
            </Link>
            <Link
              href={`/beans/${bean.id}/brews/new?method=espresso`}
              aria-disabled={offline}
              tabIndex={offline ? -1 : undefined}
              onClick={(event) => {
                if (offline) event.preventDefault();
              }}
              className={cn(
                buttonVariants({ size: "lg", variant: "outline" }),
                offline && "pointer-events-none opacity-50",
              )}
            >
              Espresso
            </Link>
          </div>
        </section>
        <section>
          <div className="mb-4 flex items-baseline justify-between">
            <h2 className="text-2xl font-semibold">History</h2>
            <span className="text-sm text-muted-foreground">
              {brews.length} brew{brews.length === 1 ? "" : "s"} together
            </span>
          </div>
          {brews.length ? (
            <div className="flex flex-col gap-3">
              {(() => {
                // The plan only ever seeds from the newest brew of its own method (brews is
                // sorted newest-first, so the first match per method is that brew) — computed
                // once here rather than per row, so HistoryCard's copy button can still answer
                // "is this brew latest?" without an O(n²) rescan of the history.
                const latestPourover = brews.find(
                  (b) => b.method_raw === "pourover",
                )?.id;
                const latestEspresso = brews.find(
                  (b) => b.method_raw === "espresso",
                )?.id;
                return brews.map((b, i) => {
                  const plannedNext =
                    b.id === latestPourover
                      ? bean.pending_next_pourover
                      : b.id === latestEspresso
                        ? bean.pending_next_espresso
                        : null;
                  return (
                    <HistoryCard
                      key={b.id}
                      brew={b}
                      bean={bean}
                      previous={brews[i + 1]}
                      plannedNext={plannedNext}
                      offline={offline}
                      refresh={refresh}
                    />
                  );
                });
              })()}
            </div>
          ) : (
            <Empty className="border">
              <EmptyHeader>
                <EmptyMedia variant="icon">
                  <Coffee />
                </EmptyMedia>
                <EmptyTitle>No brews yet</EmptyTitle>
                <EmptyDescription>
                  Log the first brew to start the feedback loop.
                </EmptyDescription>
              </EmptyHeader>
            </Empty>
          )}
        </section>
      </div>
    </main>
  );
}
function CharacterCard({
  bean,
  photos,
}: {
  bean: BeanRow;
  photos: Notebook["beanPhotos"];
}) {
  const [preview, setPreview] = useState<PreviewPhoto | null>(null);
  const photoUrls = photos
    .map((photo) => photoUrl("bean-photos", photo.remote_path))
    .filter((url): url is string => !!url);
  const hero = photoUrls[0] ?? null;
  return (
    <Card className="overflow-hidden py-0">
      <button
        type="button"
        className="relative block aspect-[16/10] w-full bg-muted disabled:cursor-default"
        disabled={!hero}
        aria-label={hero ? `View ${bean.name} bag photo` : undefined}
        onClick={() => hero && setPreview({ urls: photoUrls, index: 0 })}
      >
        {hero ? (
          <Image
            src={hero}
            alt={`${bean.name} bag`}
            fill
            sizes="(max-width:1024px) 100vw, 55vw"
            className="object-cover"
          />
        ) : (
          <div className="grid h-full place-items-center">
            <ImageIcon className="text-muted-foreground" />
          </div>
        )}
      </button>
      <CardHeader className="pt-5">
        <p className="overline">
          {bean.roaster_name || "Coffee character card"}
        </p>
        <CardTitle className="text-3xl">
          {bean.name || "Untitled bean"}
        </CardTitle>
        <CardDescription>
          {[bean.region, bean.country].filter(Boolean).join(", ")}
        </CardDescription>
      </CardHeader>
      <CardContent className="flex flex-col gap-3 pb-5">
        {photoUrls.length > 1 && (
          <div
            className="grid grid-cols-4 gap-2"
            aria-label="Bag photo gallery"
          >
            {photoUrls.slice(1, 5).map((url, i) => (
              <button
                key={url}
                type="button"
                className="relative aspect-square overflow-hidden rounded-lg border bg-muted"
                aria-label={`View ${bean.name} bag photo ${i + 2}`}
                onClick={() => setPreview({ urls: photoUrls, index: i + 1 })}
              >
                <Image
                  src={url}
                  alt={`${bean.name} bag detail ${i + 2}`}
                  fill
                  sizes="10rem"
                  className="object-cover"
                />
              </button>
            ))}
          </div>
        )}
        <dl className="grid grid-cols-2 gap-3 text-sm">
          {[
            ["Varietal", bean.varietal],
            ["Process", bean.process],
            ["Roast", bean.roast_level],
            [
              "Roasted",
              bean.roast_date
                ? new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(
                    new Date(bean.roast_date),
                  )
                : null,
            ],
            ["Farm", bean.farm],
          ]
            .filter((x) => x[1])
            .map(([k, v]) => (
              <div key={k}>
                <dt className="text-xs text-muted-foreground">{k}</dt>
                <dd>{v}</dd>
              </div>
            ))}
        </dl>
        {bean.roaster_notes && <RoasterNoteChips notes={bean.roaster_notes} />}
      </CardContent>
      <PhotoViewer
        photo={preview}
        onIndexChange={(index) => setPreview((p) => p && { ...p, index })}
        onClose={() => setPreview(null)}
      />
    </Card>
  );
}
function PlanCard({
  method,
  recipe,
  prior,
  bean,
  data,
  offline,
  refresh,
}: {
  method: "pourover" | "espresso";
  recipe: Recipe;
  prior?: Recipe;
  bean: BeanRow;
  data: Notebook;
  offline: boolean;
  refresh: () => Promise<void>;
}) {
  const router = useRouter();
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(recipe);
  const [working, setWorking] = useState(false);
  const beanToken = useRef(bean.updated_at);
  const planQueue = useRef<Promise<unknown>>(Promise.resolve());
  const changes = prior ? brewDiff(prior, recipe) : [];
  useEffect(() => {
    beanToken.current = bean.updated_at;
  }, [bean.updated_at]);
  const queuePersist = useCallback(
    (value: Recipe | null) => {
      const job = planQueue.current.then(async () => {
        const updated = (await mutate(
          "beans",
          { id: bean.id, ...singlePendingPlanPatch(method, value) },
          beanToken.current,
        )) as BeanRow;
        beanToken.current = updated.updated_at;
        return updated;
      });
      planQueue.current = job.catch(() => undefined);
      return job;
    },
    [bean.id, method],
  );
  useEffect(() => {
    if (!editing || offline) return;
    const timeout = setTimeout(() => {
      queuePersist(draft).catch((error) =>
        toast.error(
          error instanceof Error ? error.message : "Plan autosave failed",
        ),
      );
    }, 700);
    return () => clearTimeout(timeout);
  }, [draft, editing, offline, queuePersist]);
  async function persist(value: Recipe | null) {
    setWorking(true);
    try {
      await queuePersist(value);
      toast.success(value ? "Next-brew plan updated" : "Plan discarded");
      setEditing(false);
      await refresh();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not update plan",
      );
    } finally {
      setWorking(false);
    }
  }
  async function brewDraftNow() {
    setWorking(true);
    try {
      await queuePersist(draft);
      router.push(`/beans/${bean.id}/brews/new?method=${method}`);
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not start plan",
      );
      setWorking(false);
    }
  }
  return (
    <div className="flex flex-col gap-3">
      <Card className="border-primary/40 bg-primary/5 [border-style:dashed]">
        <CardHeader>
          <div className="flex items-start justify-between gap-2">
            <CardTitle className="text-base text-primary">
              Plan for next {method}
            </CardTitle>
            <div className="flex gap-1">
              <Button
                size="sm"
                variant="ghost"
                disabled={offline || working}
                onClick={() => {
                  setDraft(recipe);
                  setEditing((value) => !value);
                }}
              >
                {editing ? "Close" : "Edit plan"}
              </Button>
              <Button
                size="icon"
                variant="ghost"
                disabled={offline || working}
                aria-label={`Discard ${method} plan`}
                onClick={() => persist(null)}
              >
                <X />
              </Button>
            </div>
          </div>
          {changes.length > 0 && (
            <CardDescription>
              <ChangeChips changes={changes} />
            </CardDescription>
          )}
        </CardHeader>
        {!editing && (
          <CardContent>
            <RecipeReadout recipe={recipe} />
          </CardContent>
        )}
      </Card>
      {/* Deliberately outside the Card above: RecipeEditor renders its own "Recipe" card, so
          nesting it inside CardContent here would double the horizontal padding around every
          field (see the identical fix in brew-editor.tsx's "Plan the next brew" section). */}
      {editing && (
        <div className="flex flex-col gap-3">
          <RecipeEditor
            recipe={draft}
            onChange={setDraft}
            method={method}
            grinders={data.grinders.filter((grinder) => !grinder.deleted_at)}
          />
          <div className="flex gap-2">
            <Button
              className="flex-1"
              disabled={working}
              onClick={() => persist(draft)}
            >
              Save plan
            </Button>
            <Button
              variant="outline"
              className="flex-1"
              disabled={working || offline}
              onClick={brewDraftNow}
            >
              Brew this now
            </Button>
          </div>
        </div>
      )}
    </div>
  );
}
function HistoryCard({
  brew,
  bean,
  previous,
  plannedNext,
  offline,
  refresh,
}: {
  brew: BrewRow;
  bean: BeanRow;
  previous?: BrewRow;
  plannedNext?: Recipe | null;
  offline: boolean;
  refresh: () => Promise<void>;
}) {
  const [working, setWorking] = useState(false);
  const [preview, setPreview] = useState<PreviewPhoto | null>(null);
  const changes = previous ? brewDiff(previous.recipe, brew.recipe) : [];
  async function deleteBrew() {
    if (working) return;
    setWorking(true);
    try {
      await mutate(
        "brews",
        { id: brew.id, deleted_at: new Date().toISOString() },
        brew.updated_at,
      );
      await mutate("beans", { id: bean.id }, bean.updated_at);
      toast.success("Brew removed from history");
      await refresh();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not remove brew",
      );
    } finally {
      setWorking(false);
    }
  }
  return (
    <Card>
      <CardHeader>
        <div className="flex justify-between gap-3">
          <div>
            <CardTitle className="text-base">
              {new Intl.DateTimeFormat(undefined, {
                dateStyle: "medium",
              }).format(new Date(brew.brewed_at))}
            </CardTitle>
            <CardDescription className="capitalize">
              {brew.method_raw}
            </CardDescription>
          </div>
          <div className="flex items-center">
            <Button
              variant="ghost"
              size="icon"
              aria-label="Copy brew as text"
              onClick={async () => {
                await navigator.clipboard.writeText(
                  brewMarkdown(bean, brew, plannedNext),
                );
                toast.success("Brew copied");
              }}
            >
              <Copy />
            </Button>
            <Link
              href={`/brews/${brew.id}/edit`}
              aria-disabled={offline || working}
              tabIndex={offline || working ? -1 : undefined}
              onClick={(event) => {
                if (offline || working) event.preventDefault();
              }}
              className={cn(
                buttonVariants({ variant: "ghost", size: "icon" }),
                (offline || working) && "pointer-events-none opacity-50",
              )}
              aria-label="Edit brew"
            >
              <Ellipsis />
            </Link>
            <AlertDialog>
              <AlertDialogTrigger
                render={
                  <Button
                    variant="ghost"
                    size="icon"
                    disabled={offline || working}
                    aria-label="Delete brew"
                  />
                }
              >
                <Trash2 />
              </AlertDialogTrigger>
              <AlertDialogContent>
                <AlertDialogHeader>
                  <AlertDialogTitle>Delete this brew?</AlertDialogTitle>
                  <AlertDialogDescription>
                    It will be removed from this bean&apos;s history on every
                    synced device.
                  </AlertDialogDescription>
                </AlertDialogHeader>
                <AlertDialogFooter>
                  <AlertDialogCancel>Cancel</AlertDialogCancel>
                  <AlertDialogAction
                    variant="destructive"
                    onClick={deleteBrew}
                    disabled={working}
                  >
                    Delete brew
                  </AlertDialogAction>
                </AlertDialogFooter>
              </AlertDialogContent>
            </AlertDialog>
          </div>
        </div>
      </CardHeader>
      <CardContent className="flex flex-col gap-3">
        {brew.photo_path && (
          <button
            type="button"
            className="relative aspect-video overflow-hidden rounded-xl border bg-muted"
            aria-label="View brew photo"
            onClick={() =>
              setPreview({
                urls: [photoUrl("brew-photos", brew.photo_path)!],
                index: 0,
              })
            }
          >
            <Image
              src={photoUrl("brew-photos", brew.photo_path)!}
              alt="Brew"
              fill
              sizes="(max-width:1024px) 100vw, 40vw"
              className="object-cover"
            />
          </button>
        )}
        <PhotoViewer
        photo={preview}
        onIndexChange={(index) => setPreview((p) => p && { ...p, index })}
        onClose={() => setPreview(null)}
      />
        <RecipeReadout recipe={brew.recipe} />
        <ChangeChips changes={changes} />
        <div className="flex flex-wrap gap-1">
          {brew.taste.positives.map((x) => (
            <Badge key={`+${x}`} variant="outline" className="text-positive">
              + {x}
            </Badge>
          ))}
          {brew.taste.negatives.map((x) => (
            <Badge key={`-${x}`} variant="outline" className="text-negative">
              − {x}
            </Badge>
          ))}
        </div>
        {brew.taste.note && (
          <p className="text-sm text-muted-foreground">{brew.taste.note}</p>
        )}
        {(brew.taste.rating || Object.keys(brew.taste.balance).length > 0) && (
          <p className="text-xs text-muted-foreground">
            {brew.taste.rating ? `${"★".repeat(brew.taste.rating)} · ` : ""}
            {Object.entries(brew.taste.balance)
              .map(([axis, value]) => `${axis} ${value}/5`)
              .join(" · ")}
          </p>
        )}
      </CardContent>
    </Card>
  );
}
