import { BrewEditor } from "@/components/brew-editor"; export default async function EditBrew({params}:{params:Promise<{id:string}>}){return <BrewEditor brewId={(await params).id}/>}
