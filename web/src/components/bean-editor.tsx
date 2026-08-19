"use client";
import Image from "next/image";
import { useEffect, useRef, useState } from "react";
import { useRouter } from "next/navigation";
import { ArrowDown, ArrowLeft, ArrowUp, Trash2 } from "lucide-react";
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
  FieldDescription,
  FieldGroup,
  FieldLabel,
  FieldSet,
  FieldLegend,
} from "@/components/ui/field";
import { Input } from "@/components/ui/input";
import { Textarea } from "@/components/ui/textarea";
import { ToggleGroup, ToggleGroupItem } from "@/components/ui/toggle-group";
import { PhotoViewer, type PreviewPhoto } from "@/components/photo-viewer";
import { fetchNotebook, mutate, normalizePhoto } from "@/lib/client-mutations";
import {
  normalizeTerm,
  normalizeTerms,
  type BeanPhotoRow,
  type BeanRow,
} from "@/lib/domain";
const blank = {
  name: "",
  roaster_name: "",
  country: "",
  region: "",
  farm: "",
  varietal: "",
  process: "",
  roast_level: "",
  roast_date: "",
  roaster_notes: "",
};
type Form = typeof blank;
type PhotoDraft =
  | { kind: "saved"; id: string; row: BeanPhotoRow; preview: string }
  | { kind: "new"; id: string; file: File; preview: string };
export function BeanEditor({ id }: { id?: string }) {
  const router = useRouter();
  const [form, setForm] = useState<Form>(blank),
    [preview, setPreview] = useState<PreviewPhoto | null>(null),
    [row, setRow] = useState<BeanRow | null>(null),
    [photos, setPhotos] = useState<PhotoDraft[]>([]),
    [removedPhotos, setRemovedPhotos] = useState<BeanPhotoRow[]>([]),
    [loading, setLoading] = useState(Boolean(id)),
    [loadError, setLoadError] = useState(""),
    [busy, setBusy] = useState(false),
    objectUrls = useRef(new Set<string>());
  useEffect(
    () => () => {
      for (const url of objectUrls.current) URL.revokeObjectURL(url);
      objectUrls.current.clear();
    },
    [],
  );
  useEffect(() => {
    if (id)
      fetchNotebook()
        .then((n) => {
        const b = n.beans.find((x) => x.id === id);
        if (!b) {
          setLoadError("This bean is not available.");
          return;
        }
        setRow(b);
        setPhotos(
          n.beanPhotos
            .filter((photo) => !photo.deleted_at && photo.bean_id === b.id)
            .sort((a, b) => a.order - b.order)
            .map((photo) => ({
              kind: "saved" as const,
              id: photo.id,
              row: photo,
              preview: photo.remote_path
                ? `/api/photos/bean-photos/${photo.remote_path}`
                : "",
            })),
        );
        setForm({
          name: b.name,
          roaster_name: b.roaster_name ?? "",
          country: b.country ?? "",
          region: b.region ?? "",
          farm: b.farm ?? "",
          varietal: b.varietal ?? "",
          process: b.process ?? "",
          roast_level: b.roast_level ?? "",
          roast_date: b.roast_date?.slice(0, 10) ?? "",
          roaster_notes: b.roaster_notes ?? "",
        });
        })
        .catch(() =>
          setLoadError(
            navigator.onLine
              ? "The bean editor could not be loaded."
              : "Editors are unavailable offline. Your cached notebook remains read-only.",
          ),
        )
        .finally(() => setLoading(false));
  }, [id]);
  const change = (key: keyof Form, value: string) =>
    setForm((f) => ({ ...f, [key]: value }));
  async function save(e: React.FormEvent) {
    e.preventDefault();
    if (!form.name.trim() && !photos.length) {
      toast.error("Add a name or at least one bag photo.");
      return;
    }
    setBusy(true);
    try {
      const now = new Date().toISOString(),
        beanId = row?.id ?? crypto.randomUUID();
      const savedBean = (await mutate(
        "beans",
        {
          id: beanId,
          created_at: row?.created_at ?? now,
          updated_at: now,
          deleted_at: row?.deleted_at ?? null,
          name: normalizeTerm(form.name),
          roaster_name: form.roaster_name.trim() || null,
          country: normalizeTerm(form.country) || null,
          region: normalizeTerm(form.region) || null,
          farm: normalizeTerm(form.farm) || null,
          varietal: normalizeTerm(form.varietal) || null,
          process: normalizeTerm(form.process) || null,
          roast_level: normalizeTerm(form.roast_level) || null,
          roast_date: form.roast_date
            ? new Date(`${form.roast_date}T12:00:00Z`).toISOString()
            : null,
          roaster_notes:
            normalizeTerms(form.roaster_notes.split(",")).join(", ") || null,
          my_flavor_tags: row?.my_flavor_tags ?? [],
          finished_at: row?.finished_at ?? null,
          pending_next_pourover: row?.pending_next_pourover ?? null,
          pending_next_espresso: row?.pending_next_espresso ?? null,
        },
        row?.updated_at,
      )) as BeanRow;
      setRow(savedBean);
      for (const [order, photo] of photos.entries())
        if (photo.kind === "saved" && photo.row.order !== order) {
          const savedPhoto = (await mutate(
            "bean_photos",
            { id: photo.row.id, order },
            photo.row.updated_at,
          )) as BeanPhotoRow;
          setPhotos((current) =>
            current.map((draft) =>
              draft.id === savedPhoto.id && draft.kind === "saved"
                ? { ...draft, row: savedPhoto }
                : draft,
            ),
          );
        }
      for (const photo of removedPhotos) {
        await mutate(
          "bean_photos",
          { id: photo.id, deleted_at: now },
          photo.updated_at,
        );
        setRemovedPhotos((current) =>
          current.filter((candidate) => candidate.id !== photo.id),
        );
      }
      for (const [order, photo] of photos.entries()) {
        if (photo.kind !== "new") continue;
        const { blob, hash } = await normalizePhoto(photo.file),
          path = `${photo.id.toLowerCase()}/${hash}.jpg`;
        const upload = await fetch(`/api/photos/bean-photos/${path}`, {
          method: "PUT",
          headers: { "Content-Type": "image/jpeg" },
          body: blob,
        });
        if (!upload.ok) throw new Error("A bag photo could not be uploaded.");
        const savedPhoto = (await mutate("bean_photos", {
          id: photo.id,
          created_at: now,
          updated_at: now,
          deleted_at: null,
          order,
          bean_id: beanId,
          remote_path: path,
        })) as BeanPhotoRow;
        setPhotos((current) =>
          current.map((draft) =>
            draft.id === savedPhoto.id
              ? {
                  kind: "saved",
                  id: savedPhoto.id,
                  row: savedPhoto,
                  preview: draft.preview,
                }
              : draft,
          ),
        );
      }
      toast.success(row ? "Bean updated" : "Bean added");
      router.push(`/beans/${beanId}`);
      router.refresh();
    } catch (error) {
      toast.error(
        error instanceof Error ? error.message : "Could not save bean",
      );
    } finally {
      setBusy(false);
    }
  }
  function movePhoto(index: number, direction: -1 | 1) {
    setPhotos((current) => {
      const next = [...current],
        target = index + direction;
      if (target < 0 || target >= next.length) return current;
      [next[index], next[target]] = [next[target], next[index]];
      return next;
    });
  }
  function removePhoto(index: number) {
    const photo = photos[index];
    setPhotos((current) => current.filter((_, i) => i !== index));
    if (photo.kind === "saved")
      setRemovedPhotos((current) => [...current, photo.row]);
    else {
      URL.revokeObjectURL(photo.preview);
      objectUrls.current.delete(photo.preview);
    }
  }
  function addPhotos(files: File[]) {
    const room = Math.max(0, 5 - photos.length);
    const additions = files.slice(0, room).map((file) => {
      const preview = URL.createObjectURL(file);
      objectUrls.current.add(preview);
      return {
        kind: "new" as const,
        id: crypto.randomUUID(),
        file,
        preview,
      };
    });
    setPhotos((current) => [...current, ...additions]);
  }
  if (loading)
    return <main className="mx-auto max-w-2xl px-4 py-20">Loading bean…</main>;
  if (loadError)
    return (
      <main className="mx-auto max-w-2xl px-4 py-20">
        <h1 className="text-2xl font-semibold">Bean editor unavailable</h1>
        <p className="mt-2 text-muted-foreground">{loadError}</p>
        <Button className="mt-5" variant="outline" onClick={() => router.back()}>
          <ArrowLeft data-icon="inline-start" /> Back
        </Button>
      </main>
    );
  const previewUrls = photos
    .map((photo) => photo.preview)
    .filter((url): url is string => !!url);
  return (
    <EditorFrame title={row ? "Edit bean" : "Add bean"}>
      <form onSubmit={save}>
        <FieldGroup>
          <Card>
            <CardHeader>
              <CardTitle>Bag character</CardTitle>
              <CardDescription>
                The photo and printed facts make this bean recognizable on the
                shelf.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <FieldGroup>
                <Field>
                  <FieldLabel htmlFor="name">Coffee name</FieldLabel>
                  <Input
                    id="name"
                    value={form.name}
                    onChange={(e) => change("name", e.target.value)}
                    placeholder="La Femme d'Argent"
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="roaster">Roaster</FieldLabel>
                  <Input
                    id="roaster"
                    value={form.roaster_name}
                    onChange={(e) => change("roaster_name", e.target.value)}
                    placeholder="Voyager Craft Coffee"
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="photos">Bag photos</FieldLabel>
                  {photos.length > 0 && (
                    <div className="grid grid-cols-2 gap-3 sm:grid-cols-3">
                      {photos.map((photo, index) => (
                        <div
                          key={photo.id}
                          className="overflow-hidden rounded-xl border bg-card"
                        >
                          <button
                            type="button"
                            className="relative block aspect-square w-full bg-muted disabled:cursor-default"
                            disabled={!photo.preview}
                            aria-label={`View bag photo ${index + 1}`}
                            onClick={() =>
                              photo.preview &&
                              setPreview({
                                urls: previewUrls,
                                index: previewUrls.indexOf(photo.preview),
                              })
                            }
                          >
                            {photo.preview && (
                              <Image
                                src={photo.preview}
                                alt={`Bag photo ${index + 1}`}
                                fill
                                sizes="(max-width:640px) 45vw, 210px"
                                className="object-cover"
                              />
                            )}
                          </button>
                          <div className="flex items-center justify-center gap-1 p-1">
                            <Button
                              type="button"
                              size="icon"
                              variant="ghost"
                              aria-label={`Move photo ${index + 1} earlier`}
                              disabled={index === 0}
                              onClick={() => movePhoto(index, -1)}
                            >
                              <ArrowUp />
                            </Button>
                            <Button
                              type="button"
                              size="icon"
                              variant="ghost"
                              aria-label={`Move photo ${index + 1} later`}
                              disabled={index === photos.length - 1}
                              onClick={() => movePhoto(index, 1)}
                            >
                              <ArrowDown />
                            </Button>
                            <Button
                              type="button"
                              size="icon"
                              variant="ghost"
                              aria-label={`Remove photo ${index + 1}`}
                              onClick={() => removePhoto(index)}
                            >
                              <Trash2 />
                            </Button>
                          </div>
                        </div>
                      ))}
                    </div>
                  )}
                  <PhotoViewer
                    photo={preview}
                    onIndexChange={(index) =>
                      setPreview((p) => p && { ...p, index })
                    }
                    onClose={() => setPreview(null)}
                  />
                  <Input
                    id="photos"
                    type="file"
                    accept="image/*"
                    multiple
                    disabled={photos.length >= 5}
                    onChange={(event) => {
                      addPhotos(Array.from(event.target.files ?? []));
                      event.currentTarget.value = "";
                    }}
                  />
                  <FieldDescription>
                    Up to five ordered photos. Images are oriented, resized to
                    1400px, and encoded as JPEG before upload.
                  </FieldDescription>
                  {photos.length > 0 && (
                    <p className="text-sm">
                      {photos.length} of 5 photos · use the arrows to set the
                      shelf and gallery order before saving
                    </p>
                  )}
                </Field>
              </FieldGroup>
            </CardContent>
          </Card>
          <Card>
            <CardHeader>
              <CardTitle>Roaster facts</CardTitle>
              <CardDescription>
                Everything is optional; add only what the bag tells you.
              </CardDescription>
            </CardHeader>
            <CardContent>
              <FieldGroup>
                <div className="grid gap-4 sm:grid-cols-2">
                  {[
                    ["country", "Country"],
                    ["region", "Region"],
                    ["farm", "Farm"],
                    ["varietal", "Varietal"],
                  ].map(([key, label]) => (
                    <Field key={key}>
                      <FieldLabel htmlFor={key}>{label}</FieldLabel>
                      <Input
                        id={key}
                        value={form[key as keyof Form]}
                        onChange={(e) =>
                          change(key as keyof Form, e.target.value)
                        }
                      />
                    </Field>
                  ))}
                </div>
                <FieldSet>
                  <FieldLegend>Process</FieldLegend>
                  <Input
                    id="process"
                    value={form.process}
                    onChange={(event) => change("process", event.target.value)}
                    placeholder="Washed, co-ferment, thermal shock…"
                  />
                  <p className="text-xs text-muted-foreground">
                    or pick a common one
                  </p>
                  <ToggleGroup
                    value={[form.process]}
                    onValueChange={(v) => change("process", v[0] ?? "")}
                  >
                    <ToggleGroupItem value="Washed">Washed</ToggleGroupItem>
                    <ToggleGroupItem value="Natural">Natural</ToggleGroupItem>
                    <ToggleGroupItem value="Honey">Honey</ToggleGroupItem>
                    <ToggleGroupItem value="Anaerobic">
                      Anaerobic
                    </ToggleGroupItem>
                  </ToggleGroup>
                </FieldSet>
                <Field>
                  <FieldLabel htmlFor="roast">Roast level</FieldLabel>
                  <Input
                    id="roast"
                    list="roasts"
                    value={form.roast_level}
                    onChange={(e) => change("roast_level", e.target.value)}
                  />
                  <datalist id="roasts">
                    <option>Light</option>
                    <option>Medium-Light</option>
                    <option>Medium</option>
                    <option>Medium-Dark</option>
                    <option>Dark</option>
                  </datalist>
                </Field>
                <Field>
                  <FieldLabel htmlFor="roast-date">Roast date</FieldLabel>
                  <Input
                    id="roast-date"
                    type="date"
                    value={form.roast_date}
                    onChange={(e) => change("roast_date", e.target.value)}
                  />
                </Field>
                <Field>
                  <FieldLabel htmlFor="notes">Roaster notes</FieldLabel>
                  <Textarea
                    id="notes"
                    value={form.roaster_notes}
                    onChange={(e) => change("roaster_notes", e.target.value)}
                    placeholder="Dates, vanilla, apple"
                  />
                  <FieldDescription>
                    Separate printed notes with commas to create chips.
                  </FieldDescription>
                </Field>
              </FieldGroup>
            </CardContent>
          </Card>
          <div className="sticky bottom-0 flex gap-3 border-t bg-background/95 py-3 pb-[max(.75rem,env(safe-area-inset-bottom))] backdrop-blur">
            <Button
              type="button"
              variant="outline"
              onClick={() => router.back()}
              className="flex-1"
            >
              Cancel
            </Button>
            <Button type="submit" disabled={busy} className="flex-1">
              {busy ? "Saving…" : "Save bean"}
            </Button>
          </div>
        </FieldGroup>
      </form>
    </EditorFrame>
  );
}
function EditorFrame({
  title,
  children,
}: {
  title: string;
  children: React.ReactNode;
}) {
  return (
    <main className="mx-auto max-w-2xl px-4 py-5 w-[calc(100%-var(--spacing)*10)]">
      <Button variant="ghost" onClick={() => history.back()}>
        <ArrowLeft data-icon="inline-start" />
        Back
      </Button>
      <div className="mb-6 mt-3">
        <p className="overline">Coffee character card</p>
        <h1 className="text-3xl font-semibold">{title}</h1>
      </div>
      {children}
    </main>
  );
}
