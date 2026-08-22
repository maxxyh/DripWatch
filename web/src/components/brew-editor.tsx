"use client";
import Image from "next/image";
import { useCallback, useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, CornerDownRight, Pause, Play } from "lucide-react";
import { toast } from "sonner";
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
  FieldGroup,
  FieldLabel,
  FieldSet,
  FieldLegend,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Switch } from "@/components/ui/switch";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { RecipeEditor } from "./recipe-editor";
import {
  BrewStatGrid,
  ChangeChips,
  PourPlanList,
  RoasterNoteChips,
} from "./recipe-readout";
import { NumericStepper } from "./numeric-stepper";
import { PhotoViewer, type PreviewPhoto } from "./photo-viewer";
import { TermField } from "./term-field";
import { TimeInput } from "./time-input";
import { cn } from "@/lib/utils";
import { fetchNotebook, mutate, normalizePhoto } from "@/lib/client-mutations";
import {
  asPlanSeed,
  brewDiff,
  emptyRecipe,
  emptyTaste,
  newPourover,
  normalizeTerms,
  photoUrl,
  singlePendingPlanPatch,
  type BeanRow,
  type BrewRow,
  type Notebook,
  type Recipe,
  type Taste,
} from "@/lib/domain";
type Method = "pourover" | "espresso";
function dateInputValue(iso: string) {
  const date = new Date(iso);
  const local = new Date(date.getTime() - date.getTimezoneOffset() * 60_000);
  return local.toISOString().slice(0, 10);
}
export function BrewEditor({
  beanId,
  brewId,
  initialMethod = "pourover",
  initialPhase = "recipe",
}: {
  beanId?: string;
  brewId?: string;
  initialMethod?: Method;
  initialPhase?: "recipe" | "taste";
}) {
  const router = useRouter();
  const [book, setBook] = useState<Notebook | null>(null),
    [bean, setBean] = useState<BeanRow | null>(null),
    [existing, setExisting] = useState<BrewRow | null>(null),
    [method, setMethod] = useState<Method>(initialMethod),
    [phase, setPhase] = useState<"recipe" | "brewing" | "taste">(
      initialPhase,
    ),
    [recipe, setRecipe] = useState<Recipe>(emptyRecipe()),
    [taste, setTaste] = useState<Taste>(emptyTaste()),
    [plan, setPlan] = useState(false),
    [planSeeded, setPlanSeeded] = useState(false),
    [next, setNext] = useState<Recipe>(emptyRecipe()),
    [photoFile, setPhotoFile] = useState<File | null>(null),
    [removePhoto, setRemovePhoto] = useState(false),
    [preview, setPreview] = useState<PreviewPhoto | null>(null),
    [brewedAt, setBrewedAt] = useState(new Date().toISOString()),
    [loadError, setLoadError] = useState(""),
    [busy, setBusy] = useState(false),
    [elapsed, setElapsed] = useState(0),
    [running, setRunning] = useState(false),
    started = useRef(0),
    newBrewId = useRef(crypto.randomUUID()),
    brewUpdatedAt = useRef<string | null>(null),
    beanUpdatedAt = useRef<string | null>(null),
    originalPhotoPath = useRef<string | null>(null),
    mutationQueue = useRef<Promise<unknown>>(Promise.resolve()),
    beanQueue = useRef<Promise<unknown>>(Promise.resolve()),
    autosaveReady = useRef(false);
  useEffect(() => {
    fetchNotebook()
      .then((n) => {
        setBook(n);
        const brew = brewId ? n.brews.find((b) => b.id === brewId) : undefined,
          b = n.beans.find((x) => x.id === (beanId ?? brew?.bean_id));
        if (!b) {
          setLoadError("This brew is not available.");
          return;
        }
        setBean(b);
        beanUpdatedAt.current = b.updated_at;
        if (brew) {
          setExisting(brew);
          brewUpdatedAt.current = brew.updated_at;
          setMethod(brew.method_raw);
          setRecipe(brew.recipe);
          setElapsed(
            brew.recipe[
              brew.method_raw === "pourover"
                ? "totalDrawdownSec"
                : "shotTimeSec"
            ] ?? 0,
          );
          setTaste(brew.taste);
          setBrewedAt(brew.brewed_at);
          originalPhotoPath.current = brew.photo_path;
          const pending =
              brew.method_raw === "pourover"
                ? b.pending_next_pourover
                : b.pending_next_espresso,
            latestBrew = n.brews
              .filter(
                (candidate) =>
                  !candidate.deleted_at &&
                  candidate.bean_id === b.id,
              )
              .sort((left, right) =>
                right.brewed_at.localeCompare(left.brewed_at),
              )[0],
            activePlan = latestBrew?.id === brew.id ? pending : null;
          setPlan(!!activePlan);
          setPlanSeeded(!!activePlan);
          setNext(activePlan ?? asPlanSeed(brew.recipe));
          return;
        }
        const pending =
            initialMethod === "pourover"
              ? b.pending_next_pourover
              : b.pending_next_espresso,
          prior = n.brews
            .filter(
              (x) =>
                !x.deleted_at &&
                x.bean_id === b.id &&
                x.method_raw === initialMethod,
            )
            .sort((a, b) => b.brewed_at.localeCompare(a.brewed_at))[0];
        const seed =
          pending ??
          (prior ? asPlanSeed(prior.recipe) : undefined) ??
          (initialMethod === "pourover" ? newPourover() : emptyRecipe());
        setRecipe(seed);
        setNext(asPlanSeed(seed));
      })
      .catch(() =>
        setLoadError(
          navigator.onLine
            ? "The brew editor could not be loaded."
            : "Editors are unavailable offline. Your cached notebook remains read-only.",
        ),
      );
  }, [beanId, brewId, initialMethod]);
  const persistExisting = useCallback(
    (patch: Record<string, unknown>) => {
      if (!existing) return Promise.resolve(null);
      const job = mutationQueue.current.then(async () => {
        const updated = (await mutate(
          "brews",
          { id: existing.id, ...patch },
          brewUpdatedAt.current ?? existing.updated_at,
        )) as BrewRow;
        brewUpdatedAt.current = updated.updated_at;
        return updated;
      });
      mutationQueue.current = job.catch(() => undefined);
      return job;
    },
    [existing],
  );
  const syncPendingPlan = useCallback(
    (draft: Recipe | null, currentBrewedAt: string) => {
      if (!bean || !existing || !book) return Promise.resolve(null);
      const isNewest = !book.brews.some(
        (candidate) =>
          !candidate.deleted_at &&
          candidate.bean_id === bean.id &&
          candidate.id !== existing.id &&
          candidate.brewed_at > currentBrewedAt,
      );
      if (!isNewest) return Promise.resolve(null);
      const job = beanQueue.current.then(async () => {
        const updated = (await mutate(
          "beans",
          { id: bean.id, ...singlePendingPlanPatch(method, draft) },
          beanUpdatedAt.current ?? bean.updated_at,
        )) as BeanRow;
        beanUpdatedAt.current = updated.updated_at;
        return updated;
      });
      beanQueue.current = job.catch(() => undefined);
      return job;
    },
    [bean, book, existing, method],
  );
  useEffect(() => {
    if (!existing || !autosaveReady.current) {
      if (existing) autosaveReady.current = true;
      return;
    }
    const timeout = setTimeout(async () => {
      try {
        await persistExisting({
          recipe,
          taste,
          brewed_at: brewedAt,
          next_recipe_draft: null,
        });
        await syncPendingPlan(plan ? next : null, brewedAt);
      } catch (error) {
        toast.error(error instanceof Error ? error.message : "Autosave failed");
      }
    }, 700);
    return () => clearTimeout(timeout);
  }, [
    brewedAt,
    existing,
    next,
    persistExisting,
    plan,
    recipe,
    syncPendingPlan,
    taste,
  ]);
  useEffect(() => {
    if (!running) return;
    started.current = Date.now() - elapsed * 1000;
    const timer = setInterval(
      () => setElapsed((Date.now() - started.current) / 1000),
      100,
    );
    return () => clearInterval(timer);
  }, [running, elapsed]);
  if (loadError)
    return (
      <main className="mx-auto w-full max-w-2xl px-4 py-20">
        <h1 className="text-2xl font-semibold">Brew editor unavailable</h1>
        <p className="mt-2 text-muted-foreground">{loadError}</p>
        <Button className="mt-5" variant="outline" onClick={() => router.back()}>
          <ArrowLeft data-icon="inline-start" /> Back
        </Button>
      </main>
    );
  if (!book || !bean)
    return <main className="mx-auto w-full max-w-2xl px-4 py-20">Loading brew…</main>;
  const activeBean = bean;
  const previousTastes = book.brews
    .filter(
      (candidate) =>
        !candidate.deleted_at &&
        candidate.id !== existing?.id &&
        candidate.bean_id === activeBean.id &&
        candidate.method_raw === method &&
        (candidate.taste.note ||
          candidate.taste.positives.length ||
          candidate.taste.negatives.length ||
          candidate.taste.rating ||
          Object.keys(candidate.taste.balance).length),
    )
    .sort((a, b) => b.brewed_at.localeCompare(a.brewed_at))
    .slice(0, 3);
  const canPlanNext = !book.brews.some(
    (candidate) =>
      !candidate.deleted_at &&
      candidate.bean_id === activeBean.id &&
      candidate.id !== existing?.id &&
      candidate.brewed_at > brewedAt,
  );
  function addTerm(value: string, positive: boolean) {
    const term = value.trim();
    if (!term) return;
    setTaste((t) =>
      positive
        ? { ...t, positives: normalizeTerms([...t.positives, term]) }
        : { ...t, negatives: normalizeTerms([...t.negatives, term]) },
    );
  }
  async function persistPhoto(file: File | null, remove = false) {
    if (!existing) return;
    setBusy(true);
    try {
      let photoPath = remove ? null : originalPhotoPath.current;
      if (file) {
        const { blob, hash } = await normalizePhoto(file);
        photoPath = `${existing.id.toLowerCase()}/${hash}.jpg`;
        const upload = await fetch(`/api/photos/brew-photos/${photoPath}`, {
          method: "PUT",
          headers: { "Content-Type": "image/jpeg" },
          body: blob,
        });
        if (!upload.ok)
          throw new Error("The brew photo could not be uploaded.");
      }
      const updated = await persistExisting({ photo_path: photoPath });
      if (updated) {
        originalPhotoPath.current = updated.photo_path;
        setExisting(updated);
        setPhotoFile(null);
        setRemovePhoto(false);
      }
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not save brew photo",
      );
    } finally {
      setBusy(false);
    }
  }
  async function startBrew() {
    if (existing) {
      setPhase("brewing");
      return;
    }
    setBusy(true);
    try {
      const now = new Date().toISOString();
      const created = (await mutate("brews", {
        id: newBrewId.current,
        created_at: now,
        updated_at: now,
        deleted_at: null,
        brewed_at: brewedAt,
        method_raw: method,
        brewers: [],
        recipe,
        taste,
        next_recipe_draft: null,
        photo_path: null,
        bean_id: activeBean.id,
      })) as BrewRow;
      setExisting(created);
      brewUpdatedAt.current = created.updated_at;
      setBrewedAt(created.brewed_at);
      autosaveReady.current = true;
      const key =
        method === "pourover"
          ? "pending_next_pourover"
          : "pending_next_espresso";
      const updatedBean = (await mutate(
        "beans",
        {
          id: activeBean.id,
          ...(activeBean[key]
            ? singlePendingPlanPatch(method, null)
            : { [key]: null }),
        },
        activeBean.updated_at,
      )) as BeanRow;
      setBean(updatedBean);
      beanUpdatedAt.current = updatedBean.updated_at;
      setPhase("brewing");
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not start brew",
      );
    } finally {
      setBusy(false);
    }
  }
  function captureObservedTime() {
    const key =
      method === "pourover" ? "totalDrawdownSec" : "shotTimeSec";
    const observed = {
      ...recipe,
      [key]: Math.round(elapsed) || recipe[key],
    };
    setRunning(false);
    setRecipe(observed);
    return observed;
  }
  async function finishBrewing() {
    const observed = captureObservedTime();
    if (existing) {
      try {
        await persistExisting({ recipe: observed });
      } catch (error) {
        toast.error(
          error instanceof Error
            ? error.message
            : "Could not save the observed time",
        );
        return;
      }
    }
    setPhase("taste");
  }
  async function save() {
    setBusy(true);
    try {
      const now = new Date().toISOString(),
        id = existing?.id ?? newBrewId.current,
        observed = {
          ...recipe,
          [method === "pourover" ? "totalDrawdownSec" : "shotTimeSec"]:
            Math.round(elapsed) ||
            recipe[method === "pourover" ? "totalDrawdownSec" : "shotTimeSec"],
        };
      let photoPath = removePhoto ? null : (existing?.photo_path ?? null);
      if (photoFile) {
        const { blob, hash } = await normalizePhoto(photoFile);
        photoPath = `${id.toLowerCase()}/${hash}.jpg`;
        const upload = await fetch(`/api/photos/brew-photos/${photoPath}`, {
          method: "PUT",
          headers: { "Content-Type": "image/jpeg" },
          body: blob,
        });
        if (!upload.ok)
          throw new Error("The brew photo could not be uploaded.");
      }
      if (existing) {
        await persistExisting({
          brewed_at: brewedAt,
          recipe: observed,
          taste,
          next_recipe_draft: null,
          photo_path: photoPath,
        });
      } else {
        await mutate("brews", {
          id,
          created_at: now,
          updated_at: now,
          deleted_at: null,
          brewed_at: brewedAt,
          method_raw: method,
          brewers: [],
          recipe: observed,
          taste,
          next_recipe_draft: null,
          photo_path: photoPath,
          bean_id: activeBean.id,
        });
      }
      const isNewest = !book?.brews.some(
        (b) =>
          !b.deleted_at &&
          b.bean_id === activeBean.id &&
          b.id !== id &&
          b.brewed_at > brewedAt,
      );
      if (isNewest) {
        const updatedBean = (await mutate(
          "beans",
          {
            id: activeBean.id,
            ...singlePendingPlanPatch(method, plan ? next : null),
          },
          beanUpdatedAt.current ?? activeBean.updated_at,
        )) as BeanRow;
        beanUpdatedAt.current = updatedBean.updated_at;
      }
      toast.success(existing ? "Brew updated" : "Brew saved");
      router.push(`/beans/${activeBean.id}`);
      router.refresh();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not save brew",
      );
    } finally {
      setBusy(false);
    }
  }
  return (
    <main className="mx-auto w-full max-w-2xl px-4 py-5">
      <Button variant="ghost" onClick={() => router.back()}>
        <ArrowLeft data-icon="inline-start" />
        Back
      </Button>
      <div className="mb-5 mt-3">
        <div className="flex items-end justify-between gap-4">
          <div>
            <p className="overline">{activeBean.name}</p>
            <h1 className="text-3xl font-semibold">
              {existing ? "Edit" : "New"} {method}
            </h1>
          </div>
          <Field className="w-auto">
            <FieldLabel htmlFor="brew-date">Brew date</FieldLabel>
            <Input
              id="brew-date"
              type="date"
              value={dateInputValue(brewedAt)}
              onChange={(event) => {
                if (!event.target.value) return;
                setBrewedAt(
                  new Date(`${event.target.value}T12:00:00`).toISOString(),
                );
              }}
            />
          </Field>
        </div>
      </div>
      <Tabs
        value={phase}
        onValueChange={(value) => {
          if (phase === "brewing" && value !== "brewing") {
            captureObservedTime();
          }
          setPhase(value);
        }}
      >
        <TabsList className="mb-5 grid w-full grid-cols-3">
          <TabsTrigger value="recipe">1 · Recipe</TabsTrigger>
          <TabsTrigger value="brewing" disabled={!existing}>
            2 · Brewing
          </TabsTrigger>
          <TabsTrigger value="taste" disabled={!existing}>
            3 · Taste
          </TabsTrigger>
        </TabsList>
      </Tabs>
      {phase === "recipe" && (
        <RecipeEditor
          recipe={recipe}
          onChange={setRecipe}
          method={method}
          grinders={book.grinders.filter((g) => !g.deleted_at)}
        />
      )}{" "}
      {phase === "brewing" && (
        <div className="flex flex-col gap-4">
          <Card>
            <CardHeader>
              <CardTitle>Follow the recipe</CardTitle>
              <CardDescription className="font-mono">
                {recipe.grinderName} · {recipe.grindMajor}
                {recipe.grindClickOffset
                  ? ` (${recipe.grindClickOffset > 0 ? "+" : ""}${recipe.grindClickOffset})`
                  : ""}
              </CardDescription>
            </CardHeader>
            <CardContent className="flex flex-col gap-4">
              <BrewStatGrid recipe={recipe} method={method} onChange={setRecipe} />
              {method === "pourover" &&
                (recipe.pours.length > 0 || (recipe.pourCount ?? 0) > 0) && (
                <PourPlanList recipe={recipe} onChange={setRecipe} />
              )}
              {activeBean.roaster_notes && (
                <div className="flex flex-col gap-1.5 border-t pt-3">
                  <span className="text-xs font-semibold tracking-wide text-muted-foreground uppercase">
                    Roaster notes
                  </span>
                  <RoasterNoteChips notes={activeBean.roaster_notes} />
                </div>
              )}
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>
                {method === "pourover" ? "Total drawdown" : "Shot time"}
              </CardTitle>
              <CardDescription>
                Stopwatch stores the rounded observed time.
              </CardDescription>
            </CardHeader>
            <CardContent className="flex items-center justify-between">
              <TimeInput
                id="observed-time"
                aria-label={method === "pourover" ? "Drawdown time" : "Shot time"}
                seconds={Math.round(elapsed)}
                onChange={(seconds) => setElapsed(seconds ?? 0)}
                className="h-auto w-40 rounded-none border-0 bg-transparent px-0 font-mono text-5xl tabular-nums shadow-none focus-visible:ring-0 md:text-5xl dark:bg-transparent"
              />
              <Button size="lg" onClick={() => setRunning((x) => !x)}>
                {running ? (
                  <Pause data-icon="inline-start" />
                ) : (
                  <Play data-icon="inline-start" />
                )}
                {running ? "Pause" : "Start"}
              </Button>
            </CardContent>
            {method === "espresso" && (
              <CardContent className="border-t pt-4">
                <Field>
                  <FieldLabel htmlFor="live-yield">Yield (g)</FieldLabel>
                  <NumericStepper
                    id="live-yield"
                    step={0.1}
                    min={0}
                    value={recipe.yieldGrams}
                    onChange={(value) =>
                      setRecipe({
                        ...recipe,
                        yieldGrams: value,
                      })
                    }
                  />
                </Field>
              </CardContent>
            )}
          </Card>
        </div>
      )}
      {phase === "taste" && (
        <div className="flex flex-col gap-4">
          {activeBean.roaster_notes && (
            <Card>
              <CardHeader>
                <CardTitle>Roaster notes</CardTitle>
                <CardDescription>{activeBean.roaster_notes}</CardDescription>
              </CardHeader>
            </Card>
          )}
          <TasteEditor
            taste={taste}
            setTaste={setTaste}
            addTerm={addTerm}
            previous={previousTastes}
          />
          <Card>
            <CardHeader>
              <CardTitle>Brew photo</CardTitle>
              <CardDescription>
                Optionally keep one visual note with this brew.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <FieldGroup>
                {existing?.photo_path && !removePhoto && (
                  <button
                    type="button"
                    className="relative aspect-video overflow-hidden rounded-xl border bg-muted"
                    aria-label="View brew photo"
                    onClick={() =>
                      setPreview({
                        urls: [photoUrl("brew-photos", existing.photo_path)!],
                        index: 0,
                      })
                    }
                  >
                    <Image
                      src={photoUrl("brew-photos", existing.photo_path)!}
                      alt="Saved brew"
                      fill
                      sizes="(max-width:672px) 100vw, 640px"
                      className="object-cover"
                    />
                  </button>
                )}
                <PhotoViewer
                  photo={preview}
                  onIndexChange={(index) =>
                    setPreview((p) => p && { ...p, index })
                  }
                  onClose={() => setPreview(null)}
                />
                <Field>
                  <FieldLabel htmlFor="brew-photo">
                    {existing?.photo_path ? "Replace photo" : "Add photo"}
                  </FieldLabel>
                  <Input
                    id="brew-photo"
                    type="file"
                    accept="image/*"
                  onChange={(event) => {
                      const file = event.target.files?.[0] ?? null;
                      setPhotoFile(file);
                      setRemovePhoto(false);
                      if (file) void persistPhoto(file);
                    }}
                  />
                </Field>
                {existing?.photo_path && (
                  <Button
                    type="button"
                    variant="outline"
                    onClick={() => {
                      const removing = !removePhoto;
                      setRemovePhoto(removing);
                      setPhotoFile(null);
                      void persistPhoto(null, removing);
                    }}
                  >
                    {removePhoto ? "Keep saved photo" : "Remove saved photo"}
                  </Button>
                )}
              </FieldGroup>
            </CardContent>
          </Card>
          {canPlanNext && (
            // Deliberately not wrapped in a Card: RecipeEditor renders its own "Recipe" card, so
            // an outer card here would double the horizontal padding around every field (a
            // dashed card's CardContent padding, plus RecipeEditor's own Card's padding again) —
            // exactly what made this section feel squeezed next to the rest of the flow. iOS's
            // RecipeEditor.swift has no card of its own for the same reason: whichever card wraps
            // it is the only one.
            <div className="flex flex-col gap-3">
              <div className="flex flex-col gap-1">
                <div className="flex items-center gap-2 text-primary">
                  <CornerDownRight className="size-4" aria-hidden />
                  <h2 className="font-heading text-base font-medium">
                    Plan the next {method}
                  </h2>
                </div>
                <p className="text-sm text-muted-foreground">
                  Measured shot time and drawdown are never carried forward
                  automatically.
                </p>
              </div>
              <div className="flex items-center justify-between gap-3">
                <FieldLabel htmlFor="plan-next-brew" className="text-sm font-normal">
                  Plan a change for next time
                </FieldLabel>
                <Switch
                  id="plan-next-brew"
                  checked={plan}
                  onCheckedChange={(on) => {
                    setPlan(on);
                    if (on && !planSeeded) {
                      setNext(asPlanSeed(recipe));
                      setPlanSeeded(true);
                    }
                  }}
                />
              </div>
              {plan && (
                <>
                  <p className="text-sm text-muted-foreground">
                    Pre-filled with what you just brewed — change only what
                    you want.
                  </p>
                  {(() => {
                    const planChanges = brewDiff(recipe, next);
                    return planChanges.length > 0 ? (
                      <ChangeChips changes={planChanges} />
                    ) : (
                      <p className="text-xs text-muted-foreground/70">
                        No changes yet — tweak a value below.
                      </p>
                    );
                  })()}
                  <RecipeEditor
                    recipe={next}
                    onChange={setNext}
                    method={method}
                    grinders={book.grinders.filter((g) => !g.deleted_at)}
                  />
                </>
              )}
            </div>
          )}
        </div>
      )}
      <div className="sticky bottom-0 mt-5 flex gap-3 border-t bg-background/95 py-3 pb-[max(.75rem,env(safe-area-inset-bottom))] backdrop-blur">
        {phase !== "recipe" && (
          <Button
            variant="outline"
            onClick={() => {
              if (phase === "brewing") captureObservedTime();
              setPhase(phase === "taste" ? "brewing" : "recipe");
            }}
          >
            Back
          </Button>
        )}
        {phase !== "taste" ? (
          <Button
            className="flex-1"
            disabled={busy}
            onClick={phase === "recipe" ? startBrew : finishBrewing}
          >
            {busy
              ? "Saving…"
              : phase === "recipe"
                ? "Start brew"
                : "Finish & log taste"}
          </Button>
        ) : (
          <Button className="flex-1" disabled={busy} onClick={save}>
            {busy ? "Saving…" : "Done"}
          </Button>
        )}
      </div>
    </main>
  );
}
/// The last few brews' tasting notes for this bean/method, grouped by date rather than pooled
/// into one flat list — each date keeps its own positive/negative coloring (mirrors the native
/// app's `PreviousNotesView`). Collapsed to the most recent date by default; terms are tappable
/// to reuse in the current taste with one tap.
function PreviousTastingNotes({
  brews,
  onAdd,
}: {
  brews: BrewRow[];
  onAdd: (value: string, positive: boolean) => void;
}) {
  const [expanded, setExpanded] = useState(false);
  if (!brews.length) return null;
  const visible = expanded ? brews : brews.slice(0, 1);
  return (
    <Field>
      <div className="flex items-baseline justify-between gap-2">
        <FieldLabel>Previous notes</FieldLabel>
        <span className="text-xs text-muted-foreground">tap a term to reuse</span>
      </div>
      <div className="flex flex-col gap-3">
        {visible.map((brew, index) => (
          <div
            key={brew.id}
            className={cn("flex flex-col gap-1.5", index > 0 && "border-t pt-3")}
          >
            <span className="text-xs font-semibold text-muted-foreground">
              {new Intl.DateTimeFormat(undefined, { dateStyle: "medium" }).format(
                new Date(brew.brewed_at),
              )}
            </span>
            {(brew.taste.positives.length > 0 || brew.taste.negatives.length > 0) && (
              <div className="flex flex-wrap gap-1.5">
                {brew.taste.positives.map((term) => (
                  <Button
                    key={`+${term}`}
                    type="button"
                    size="sm"
                    variant="outline"
                    className="text-positive"
                    onClick={() => onAdd(term, true)}
                  >
                    + {term}
                  </Button>
                ))}
                {brew.taste.negatives.map((term) => (
                  <Button
                    key={`-${term}`}
                    type="button"
                    size="sm"
                    variant="outline"
                    className="text-negative"
                    onClick={() => onAdd(term, false)}
                  >
                    − {term}
                  </Button>
                ))}
              </div>
            )}
            {brew.taste.note && (
              <p className="text-xs text-muted-foreground italic">“{brew.taste.note}”</p>
            )}
          </div>
        ))}
      </div>
      {brews.length > 1 && (
        <Button
          type="button"
          variant="ghost"
          size="sm"
          className="self-start text-primary"
          onClick={() => setExpanded((value) => !value)}
        >
          {expanded ? "Show less" : `Show ${brews.length - 1} more`}
        </Button>
      )}
    </Field>
  );
}
function TasteEditor({
  taste,
  setTaste,
  addTerm,
  previous,
}: {
  taste: Taste;
  setTaste: (t: Taste) => void;
  addTerm: (v: string, p: boolean) => void;
  previous: BrewRow[];
}) {
  return (
    <Card>
      <CardHeader>
        <CardTitle>How did it taste?</CardTitle>
        <CardDescription>
          Use + and − terms; meaning stays visible without relying on color.
        </CardDescription>
      </CardHeader>
      <CardContent>
        <FieldGroup>
          <TermField
            label="Positive (+)"
            values={taste.positives}
            tone="positive"
            placeholder="honey"
            onAdd={(v) => addTerm(v, true)}
            onRemove={(v) =>
              setTaste({
                ...taste,
                positives: taste.positives.filter((x) => x !== v),
              })
            }
          />
          <TermField
            label="Negative (−)"
            values={taste.negatives}
            tone="negative"
            placeholder="dry"
            onAdd={(v) => addTerm(v, false)}
            onRemove={(v) =>
              setTaste({
                ...taste,
                negatives: taste.negatives.filter((x) => x !== v),
              })
            }
          />
          <FieldSet>
            <FieldLegend>Taste balance</FieldLegend>
            <div className="grid gap-3 sm:grid-cols-2">
              {(["acidity", "sweetness", "bitterness", "body"] as const).map(
                (axis) => (
                  <Field key={axis}>
                    <FieldLabel className="capitalize">{axis}</FieldLabel>
                    <ToggleGroup
                      value={
                        taste.balance[axis] ? [String(taste.balance[axis])] : []
                      }
                      onValueChange={(v) =>
                        setTaste({
                          ...taste,
                          balance: {
                            ...taste.balance,
                            [axis]: v[0] ? Number(v[0]) : undefined,
                          },
                        })
                      }
                    >
                      {[1, 2, 3, 4, 5].map((n) => (
                        <ToggleGroupItem
                          key={n}
                          value={String(n)}
                          aria-label={`${axis} ${n} of 5`}
                        >
                          {n}
                        </ToggleGroupItem>
                      ))}
                    </ToggleGroup>
                  </Field>
                ),
              )}
            </div>
          </FieldSet>
          <PreviousTastingNotes brews={previous} onAdd={addTerm} />
          <Field>
            <FieldLabel>Rating</FieldLabel>
            <ToggleGroup
              value={taste.rating ? [String(taste.rating)] : []}
              onValueChange={(v) =>
                setTaste({ ...taste, rating: v[0] ? Number(v[0]) : undefined })
              }
            >
              {[1, 2, 3, 4, 5].map((n) => (
                <ToggleGroupItem
                  key={n}
                  value={String(n)}
                  aria-label={`${n} star rating`}
                >
                  ★
                </ToggleGroupItem>
              ))}
            </ToggleGroup>
          </Field>
          <Field>
            <FieldLabel htmlFor="taste-note">Taste note</FieldLabel>
            <Textarea
              id="taste-note"
              value={taste.note ?? ""}
              onChange={(e) =>
                setTaste({ ...taste, note: e.target.value || undefined })
              }
              placeholder="Opened up as it cooled…"
            />
          </Field>
        </FieldGroup>
      </CardContent>
    </Card>
  );
}
