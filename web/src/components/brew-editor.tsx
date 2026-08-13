"use client";
import Image from "next/image";
import { useCallback, useEffect, useId, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowLeft, Pause, Play, X } from "lucide-react";
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
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { Textarea } from "@/components/ui/textarea";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { RecipeEditor } from "./recipe-editor";
import { fetchNotebook, mutate, normalizePhoto } from "@/lib/client-mutations";
import {
  asPlanSeed,
  emptyRecipe,
  emptyTaste,
  gramText,
  newPourover,
  normalizeTerms,
  recipeSummary,
  suggestedTargets,
  timeText,
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
}: {
  beanId?: string;
  brewId?: string;
  initialMethod?: Method;
}) {
  const router = useRouter();
  const [book, setBook] = useState<Notebook | null>(null),
    [bean, setBean] = useState<BeanRow | null>(null),
    [existing, setExisting] = useState<BrewRow | null>(null),
    [method, setMethod] = useState<Method>(initialMethod),
    [phase, setPhase] = useState("recipe"),
    [recipe, setRecipe] = useState<Recipe>(emptyRecipe()),
    [taste, setTaste] = useState<Taste>(emptyTaste()),
    [plan, setPlan] = useState(false),
    [planSeeded, setPlanSeeded] = useState(false),
    [next, setNext] = useState<Recipe>(emptyRecipe()),
    [photoFile, setPhotoFile] = useState<File | null>(null),
    [removePhoto, setRemovePhoto] = useState(false),
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
          setTaste(brew.taste);
          setBrewedAt(brew.brewed_at);
          originalPhotoPath.current = brew.photo_path;
          setPlan(!!brew.next_recipe_draft);
          setPlanSeeded(!!brew.next_recipe_draft);
          setNext(brew.next_recipe_draft ?? asPlanSeed(brew.recipe));
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
          prior?.recipe ??
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
          candidate.method_raw === method &&
          candidate.id !== existing.id &&
          candidate.brewed_at > currentBrewedAt,
      );
      if (!isNewest) return Promise.resolve(null);
      const key =
        method === "pourover"
          ? "pending_next_pourover"
          : "pending_next_espresso";
      const job = beanQueue.current.then(async () => {
        const updated = (await mutate(
          "beans",
          { id: bean.id, [key]: draft },
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
          next_recipe_draft: plan ? next : null,
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
      <main className="mx-auto max-w-2xl px-4 py-20">
        <h1 className="text-2xl font-semibold">Brew editor unavailable</h1>
        <p className="mt-2 text-muted-foreground">{loadError}</p>
        <Button className="mt-5" variant="outline" onClick={() => router.back()}>
          <ArrowLeft data-icon="inline-start" /> Back
        </Button>
      </main>
    );
  if (!book || !bean)
    return <main className="mx-auto max-w-2xl px-4 py-20">Loading brew…</main>;
  const activeBean = bean;
  const savedPourTargets = recipe.pours.map((pour) => pour.toGrams);
  const pourTargets =
    savedPourTargets.length > 0 &&
    savedPourTargets.every((target) => target !== undefined)
      ? (savedPourTargets as number[])
      : suggestedTargets(recipe, recipe.pourCount ?? 0);
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
    .slice(0, 3)
    .map((candidate) => candidate.taste);
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
        { id: activeBean.id, [key]: null },
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
          next_recipe_draft: plan ? next : null,
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
          next_recipe_draft: plan ? next : null,
          photo_path: photoPath,
          bean_id: activeBean.id,
        });
      }
      const isNewest = !book?.brews.some(
        (b) =>
          !b.deleted_at &&
          b.bean_id === activeBean.id &&
          b.method_raw === method &&
          b.id !== id &&
          b.brewed_at > brewedAt,
      );
      if (isNewest) {
        const key =
          method === "pourover"
            ? "pending_next_pourover"
            : "pending_next_espresso";
        const updatedBean = (await mutate(
          "beans",
          { id: activeBean.id, [key]: plan ? next : null },
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
    <main className="mx-auto max-w-2xl px-4 py-5">
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
            <CardContent className="flex flex-col gap-3">
              <p className="font-mono text-lg">{recipeSummary(recipe)}</p>
              {method === "pourover" && (
                <div className="grid gap-2 sm:grid-cols-2">
                  {pourTargets.map(
                    (target, index) => {
                      const pour = recipe.pours[index];
                      return (
                        <div
                          key={pour?.id ?? index}
                          className="rounded-lg border p-3"
                        >
                          <strong className="font-mono">
                            #{index + 1} → {gramText(target)}g
                          </strong>
                          {(pour?.startSec !== undefined || pour?.style) && (
                            <p className="text-xs text-muted-foreground">
                              {pour.startSec !== undefined
                                ? `${timeText(pour.startSec)}${
                                    pour.endSec !== undefined
                                      ? `–${timeText(pour.endSec)}`
                                      : ""
                                  }`
                                : ""}
                              {pour.style ? ` · ${pour.style}` : ""}
                            </p>
                          )}
                        </div>
                      );
                    },
                  )}
                </div>
              )}
              {activeBean.roaster_notes && (
                <p className="text-sm text-muted-foreground">
                  Roaster notes: {activeBean.roaster_notes}
                </p>
              )}
            </CardContent>
          </Card>
          <details className="rounded-xl border bg-card p-4">
            <summary className="cursor-pointer font-medium">Adjust recipe</summary>
            <div className="mt-4">
              <RecipeEditor
                recipe={recipe}
                onChange={setRecipe}
                method={method}
                grinders={book.grinders.filter((g) => !g.deleted_at)}
              />
            </div>
          </details>
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
              <output
                aria-label="Elapsed brew time"
                className="font-mono text-5xl tabular-nums"
              >
                {Math.floor(elapsed / 60)}:
                {String(Math.floor(elapsed % 60)).padStart(2, "0")}
              </output>
              <Button size="lg" onClick={() => setRunning((x) => !x)}>
                {running ? (
                  <Pause data-icon="inline-start" />
                ) : (
                  <Play data-icon="inline-start" />
                )}
                {running ? "Pause" : "Start"}
              </Button>
            </CardContent>
            <CardContent className="grid grid-cols-2 gap-3 border-t pt-4">
              <Field>
                <FieldLabel htmlFor="observed-time">
                  {method === "pourover" ? "Drawdown seconds" : "Shot seconds"}
                </FieldLabel>
                <Input
                  id="observed-time"
                  type="number"
                  min="0"
                  value={Math.round(elapsed) || ""}
                  onChange={(event) =>
                    setElapsed(Math.max(0, Number(event.target.value) || 0))
                  }
                />
              </Field>
              {method === "espresso" && (
                <Field>
                  <FieldLabel htmlFor="live-yield">Yield (g)</FieldLabel>
                  <Input
                    id="live-yield"
                    type="number"
                    step="0.1"
                    value={recipe.yieldGrams ?? ""}
                    onChange={(event) =>
                      setRecipe({
                        ...recipe,
                        yieldGrams: event.target.value
                          ? Number(event.target.value)
                          : undefined,
                      })
                    }
                  />
                </Field>
              )}
            </CardContent>
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
                  <div className="relative aspect-video overflow-hidden rounded-xl border bg-muted">
                    <Image
                      src={`/api/photos/brew-photos/${existing.photo_path}`}
                      alt="Saved brew"
                      fill
                      className="object-cover"
                      unoptimized
                    />
                  </div>
                )}
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
          <Card className="border-primary/40 bg-primary/5 [border-style:dashed]">
            <CardHeader>
              <CardTitle>Plan the next {method}</CardTitle>
              <CardDescription>
                Measured shot time and drawdown are never carried forward
                automatically.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <ToggleGroup
                value={plan ? ["plan"] : []}
                onValueChange={(v) => {
                  const on = v.includes("plan");
                  setPlan(on);
                  if (on && !planSeeded) {
                    setNext(asPlanSeed(recipe));
                    setPlanSeeded(true);
                  }
                }}
              >
                <ToggleGroupItem value="plan">Plan next brew</ToggleGroupItem>
              </ToggleGroup>
              {plan && (
                <div className="mt-4">
                  <RecipeEditor
                    recipe={next}
                    onChange={setNext}
                    method={method}
                    grinders={book.grinders.filter((g) => !g.deleted_at)}
                  />
                </div>
              )}
            </CardContent>
          </Card>
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
function TasteEditor({
  taste,
  setTaste,
  addTerm,
  previous,
}: {
  taste: Taste;
  setTaste: (t: Taste) => void;
  addTerm: (v: string, p: boolean) => void;
  previous: Taste[];
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
            positive
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
          {previous.length > 0 && (
            <Field>
              <FieldLabel>Add from previous tastings</FieldLabel>
              <div className="flex flex-wrap gap-2">
                {previous.flatMap((candidate, index) => [
                  ...candidate.positives.map((term) => (
                    <Button
                      key={`${index}-positive-${term}`}
                      type="button"
                      variant="outline"
                      onClick={() =>
                        setTaste({
                          ...taste,
                          positives: normalizeTerms([
                            ...taste.positives,
                            term,
                          ]),
                        })
                      }
                    >
                      + {term}
                    </Button>
                  )),
                  ...candidate.negatives.map((term) => (
                    <Button
                      key={`${index}-negative-${term}`}
                      type="button"
                      variant="outline"
                      onClick={() =>
                        setTaste({
                          ...taste,
                          negatives: normalizeTerms([
                            ...taste.negatives,
                            term,
                          ]),
                        })
                      }
                    >
                      − {term}
                    </Button>
                  )),
                ])}
              </div>
            </Field>
          )}
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
function TermField({
  label,
  values,
  positive = false,
  onAdd,
  onRemove,
}: {
  label: string;
  values: string[];
  positive?: boolean;
  onAdd: (v: string) => void;
  onRemove: (v: string) => void;
}) {
  const inputId = useId();
  return (
    <Field>
      <FieldLabel htmlFor={inputId}>{label}</FieldLabel>
      <Input
        id={inputId}
        placeholder={positive ? "honey" : "dry"}
        onBlur={(event) => {
          onAdd(event.currentTarget.value);
          event.currentTarget.value = "";
        }}
        onKeyDown={(e) => {
          if (e.key === "Enter") {
            e.preventDefault();
            onAdd(e.currentTarget.value);
            e.currentTarget.value = "";
          }
        }}
      />
      <div className="flex flex-wrap gap-2">
        {values.map((v) => (
          <Button
            key={v}
            type="button"
            size="sm"
            variant="outline"
            className={positive ? "text-positive" : "text-negative"}
            onClick={() => onRemove(v)}
          >
            {positive ? "+" : "−"} {v}
            <X data-icon="inline-end" />
          </Button>
        ))}
      </div>
    </Field>
  );
}
