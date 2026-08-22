import { BrewEditor } from "@/components/brew-editor";

export default async function EditBrew({
  params,
  searchParams,
}: {
  params: Promise<{ id: string }>;
  searchParams: Promise<{ phase?: string }>;
}) {
  const phase = (await searchParams).phase === "taste" ? "taste" : "recipe";
  return <BrewEditor brewId={(await params).id} initialPhase={phase} />;
}
